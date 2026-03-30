#!/usr/bin/env bash

set -eu

MODE="Menu"
TARGET_WORKSPACE=""
TEMPLATE="standard"
INCLUDE_DOCS=0
FORCE=0
NO_PROMPT=0

INSTALLER_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCAL_KIT_ROOT=$(dirname "$INSTALLER_ROOT")
GLOBAL_HOME="${CODEX_HOME:-${HOME}/.codex}"
GLOBAL_KIT_ROOT="${GLOBAL_HOME}/multiagent-kit"
GLOBAL_AGENTS_PATH="${GLOBAL_HOME}/AGENTS.md"
GLOBAL_CONFIG_PATH="${GLOBAL_HOME}/config.toml"
GLOBAL_CUSTOM_AGENTS_ROOT="${GLOBAL_HOME}/agents"
GLOBAL_RULES_ROOT="${GLOBAL_HOME}/rules"
GLOBAL_SKILLS_ROOT="${GLOBAL_HOME}/skills"
GLOBAL_MANAGED_SKILLS_MANIFEST="${GLOBAL_HOME}/installer-managed-skills.manifest"
LOCAL_README="${LOCAL_KIT_ROOT}/README.md"
MANAGED_AGENT_FILES=("default.toml" "worker.toml" "explorer.toml" "reviewer.toml")

usage() {
    cat <<'EOF'
Usage:
  CodexMultiAgent.sh install-global [--force] [--no-prompt]
  CodexMultiAgent.sh apply-workspace --workspace <path> [--template standard|minimal] [--include-docs] [--force] [--no-prompt]
  CodexMultiAgent.sh menu
EOF
}

write_section() {
    printf '\n== %s ==\n' "$1"
}

ensure_directory() {
    mkdir -p "$1"
}

copy_directory_contents() {
    src="$1"
    dest="$2"

    ensure_directory "$dest"
    if [ -d "$src" ]; then
        cp -R "$src"/. "$dest"/
    fi
}

iter_top_level_sorted_paths() {
    dir="$1"
    type="$2"

    (
        LC_ALL=C
        for path in "$dir"/.* "$dir"/*; do
            case "$path" in
                "$dir"/.|"$dir"/..)
                    continue
                    ;;
            esac
            case "$type" in
                file)
                    [ -f "$path" ] || continue
                    [ -L "$path" ] && continue
                    ;;
                dir)
                    [ -d "$path" ] || continue
                    [ -L "$path" ] && continue
                    ;;
            esac
            printf '%s\n' "$path"
        done
    ) | sort | while IFS= read -r path; do
        [ -n "$path" ] || continue
        printf '%s\0' "$path"
    done
}

get_backup_stamp() {
    date +"%Y%m%d-%H%M%S"
}

backup_path_if_exists() {
    path="$1"
    backup_root="$2"
    name="$3"

    if [ ! -e "$path" ]; then
        return
    fi

    target="${backup_root}/${name}"
    ensure_directory "$(dirname "$target")"
    cp -R "$path" "$target"
}

remove_stale_installer_artifacts() {
    installer_path="$1"

    rm -rf \
        "${installer_path}/CodexMultiAgentLauncher.exe" \
        "${installer_path}/Launch-CodexMultiAgent.cmd" \
        "${installer_path}/Build-Launcher.ps1" \
        "${installer_path}/src"
}

get_source_kit_root() {
    if [ -f "${GLOBAL_KIT_ROOT}/AGENTS.md" ]; then
        printf '%s\n' "$GLOBAL_KIT_ROOT"
    else
        printf '%s\n' "$LOCAL_KIT_ROOT"
    fi
}

get_workspace_context_path() {
    workspace_path="$1"
    printf '%s\n' "${workspace_path}/WORKSPACE_CONTEXT.toml"
}

toml_get_scalar() {
    file="$1"
    section="$2"
    key="$3"

    if [ ! -f "$file" ]; then
        return 0
    fi

    awk -v section="$section" -v key="$key" '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        /^\[.*\]$/ {
            current = $0
            gsub(/^\[/, "", current)
            gsub(/\]$/, "", current)
            current = trim(current)
            next
        }
        current == section {
            lhs = $0
            sub(/=.*/, "", lhs)
            lhs = trim(lhs)
            if (lhs == key) {
                value = $0
                sub(/^[^=]*=[[:space:]]*/, "", value)
                value = trim(value)
                if (value ~ /^".*"$/) {
                    sub(/^"/, "", value)
                    sub(/"$/, "", value)
                }
                gsub(/\\"/, "\"", value)
                gsub(/\\\\/, "\\", value)
                print value
                exit
            }
        }
    ' "$file"
}

toml_get_array() {
    file="$1"
    section="$2"
    key="$3"

    if [ ! -f "$file" ]; then
        return 0
    fi

    awk -v section="$section" -v key="$key" '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        /^\[.*\]$/ {
            current = $0
            gsub(/^\[/, "", current)
            gsub(/\]$/, "", current)
            current = trim(current)
            next
        }
        current == section {
            lhs = $0
            sub(/=.*/, "", lhs)
            lhs = trim(lhs)
            if (lhs == key) {
                value = $0
                sub(/^[^=]*=[[:space:]]*/, "", value)
                value = trim(value)
                if (value ~ /^\[/ && value !~ /\]$/) {
                    while (getline nextline > 0) {
                        nextline = trim(nextline)
                        if (nextline == "" || nextline ~ /^#/) {
                            continue
                        }
                        value = value " " nextline
                        if (nextline ~ /\]$/) {
                            break
                        }
                    }
                }
                while (match(value, /"([^"\\]|\\.)*"/)) {
                    item = substr(value, RSTART + 1, RLENGTH - 2)
                    gsub(/\\"/, "\"", item)
                    gsub(/\\\\/, "\\", item)
                    print item
                    value = substr(value, RSTART + RLENGTH)
                }
                exit
            }
        }
    ' "$file"
}

load_context_array() {
    target_name="$1"
    file="$2"
    section="$3"
    key="$4"

    eval "$target_name=()"
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            eval "$target_name+=(\"\$line\")"
        fi
    done < <(toml_get_array "$file" "$section" "$key")
}

load_array_from_command() {
    target_name="$1"
    shift

    eval "$target_name=()"
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            eval "$target_name+=(\"\$line\")"
        fi
    done < <("$@")
}

write_markdown_section() {
    title="$1"
    shift

    if [ "$#" -eq 0 ]; then
        return
    fi

    printf '\n## %s\n\n' "$title"
    for item in "$@"; do
        [ -n "$item" ] && printf -- '- %s\n' "$item"
    done
}

generate_default_workspace_agents() {
    workspace_name="$1"
    template_name="$2"

    printf '# Workspace Override: %s\n\n' "$workspace_name"
    printf 'This file adds repository-specific rules on top of the global multi-agent defaults.\n'
    printf 'Root `STATE.md` is a lightweight task board; keep per-thread detail in `state/TASK-*.md`.\n'
    printf 'Global multi-agent defaults remain in effect unless this file narrows them.\n'
    if [ "$template_name" = "minimal" ]; then
        printf '\n## Minimal Repository Rules\n\n'
        printf -- '- Error log path: `ERROR_LOG.md`\n'
        printf -- '- Fill `WORKSPACE_CONTEXT.toml` first if you want project-aware generation instead of generic fallback rules\n'
        printf -- '- Keep changes small\n'
        printf -- '- Add repository-specific verification commands, source-of-truth paths, and do-not-touch paths here\n'
        printf -- '- Keep root `STATE.md` updated with board-level `route`, concrete `reason`, `owned_write_sets`, and `contract_freeze` only; use `writer_scope` and `worker_ownership_map` in the Writer Slot section\n'
        printf -- '- Put per-thread scope, write sets, reviewer notes, and verification detail in `state/TASK-*.md`\n'
        printf -- '- Use `state/TASK_TEMPLATE.md` as the starter file for new tasks\n'
        printf -- '- If multiple roles are used, append real participation to `MULTI_AGENT_LOG.md`\n'
    else
        printf '\n## Repository Facts To Fill\n\n'
        printf -- '- Primary source of truth paths\n'
        printf -- '- Shared asset paths\n'
        printf -- '- Task state directory: `state/`\n'
        printf -- '- Do-not-touch or generated paths\n'
        printf -- '- Error log path: `ERROR_LOG.md`\n'
        printf -- '- Verification commands\n'
        printf -- '- Manual approval zones\n'
        printf -- '- Worker ownership mapping when Route B is used\n'
        printf '\n## Repository Overrides\n\n'
        printf -- '- Fill `WORKSPACE_CONTEXT.toml` first if you want project-aware generation instead of generic fallback rules\n'
        printf -- '- Keep root `STATE.md` updated with board-level `route`, concrete `reason`, `owned_write_sets`, and `contract_freeze` when Route B is active; use `writer_scope` and `worker_ownership_map` in the Writer Slot section\n'
        printf -- '- Put task-specific `write_set`, scope, reviewer notes, and verification detail in `state/TASK-*.md`\n'
        printf -- '- Use `state/TASK_TEMPLATE.md` as the starter file for new tasks\n'
        printf -- '- If multiple roles are used, append real participation to `MULTI_AGENT_LOG.md` before reporting that they ran\n'
        printf -- '- Add repository-specific verification commands, hard triggers, approval zones, and worker ownership here\n'
        printf -- '- Let this repository narrow Route A/B behavior further only when it truly needs stricter local rules\n'
    fi
}

generate_default_state() {
    workspace_name="$1"

    printf '# STATE\n\n'
    printf '## Current Task\n\n'
    printf -- '- active_tasks: `n/a`\n'
    printf -- '- blocked_tasks: `n/a`\n'
    printf -- '- owned_write_sets: `n/a`\n'
    printf -- '- task_state_dir: `state/`\n'
    printf -- '- status_overview: `n/a`\n'
    printf -- '- note: `Use root STATE.md for board-level ownership and summaries. Put per-thread detail in state/TASK-*.md files.`\n'
    printf '\n## Route\n\n'
    printf -- '- route: `Route A`\n'
    printf -- '- reason: `placeholder - classify the first task as Route A or Route B before editing`\n'
    printf '\n## Writer Slot\n\n'
    printf -- '- owner: `main`\n'
    printf -- '- writer_scope: `n/a`\n'
    printf -- '- worker_ownership_map:\n'
    printf '  - `main`: `n/a`\n'
    printf '  - `worker`: `n/a`\n'
    printf '  - `reviewer`: `n/a`\n'
    printf -- '- note: `Use owned_write_sets for the root board; use writer_scope and worker_ownership_map for this section. Route A has no subagents or reviewer calls; Route B is delegated with worker and reviewer roles.`\n'
    printf '\n## Contract Freeze\n\n'
    printf -- '- contract_freeze: `n/a`\n'
    printf '\n## Seed\n\n'
    printf -- '- status: `n/a`\n'
    printf -- '- path: `n/a`\n'
    printf -- '- revision: `n/a`\n'
    printf -- '- note: `Use this section to track the active frozen seed once a spec-first task starts.`\n'
    printf '\n## Reviewer\n\n'
    printf -- '- reviewer: `n/a`\n'
    printf -- '- reviewer_target: `n/a`\n'
    printf -- '- reviewer_focus: `n/a`\n'
    printf '\n## Last Update\n\n'
    printf -- '- timestamp: `[timestamp]`\n'
    printf -- '- note: `Template generated by installer.`\n'
}

generate_default_error_log() {
    printf '# ERROR LOG\n\n'
    printf 'Append-only log for installer, execution, tool, and verification errors.\n'
    printf 'Add new entries with timestamp, location, summary, and details.\n'
    printf 'Do not rewrite existing entries; append only.\n'
}

generate_default_task_state_template() {
    printf '# TASK TEMPLATE\n\n'
    printf -- '- task_id: `TASK-TEMPLATE`\n'
    printf -- '- owner_thread: `n/a`\n'
    printf -- '- scope: `n/a`\n'
    printf -- '- write_set: `n/a`\n'
    printf -- '- route: `Route A`\n'
    printf -- '- contract_freeze: `n/a`\n'
    printf -- '- reviewer: `n/a`\n'
    printf -- '- verification: `n/a`\n'
    printf -- '- last_update: `Template generated by installer.`\n'
    printf '\n## Usage\n\n'
    printf -- '- Copy this file to `state/TASK-<id>.md` for each real task.\n'
    printf -- '- Keep root `STATE.md` as the board and keep task detail here.\n'
}

merge_context_items() {
    for item in "$@"; do
        [ -n "$item" ] && printf '%s\n' "$item"
    done | awk '!seen[$0]++'
}

compress_path_like_items() {
    merge_context_items "$@" | awk '
        {
            if ($0 ~ / / && $0 ~ /\// && $0 !~ /: /) {
                split($0, parts, /[[:space:]]+/)
                for (j in parts) {
                    if (parts[j] != "") {
                        expanded[++m] = parts[j]
                    }
                }
            } else {
                expanded[++m] = $0
            }
        }
        END {
            for (k = 1; k <= m; k++) {
                item = expanded[k]
                if (item ~ /\/\*\*$/) {
                    wildcard[substr(item, 1, length(item)-3)] = 1
                }
                items[++n] = item
            }
            for (i = 1; i <= n; i++) {
                item = items[i]
                if (item !~ / / && wildcard[item]) {
                    continue
                }
                if (!seen[item]++) {
                    print item
                }
            }
        }
    '
}

get_derived_workspace_summary() {
    context_path="$1"
    workspace_name="$2"

    summary=$(toml_get_scalar "$context_path" "workspace" "summary")
    [ -n "$summary" ] || summary=$(toml_get_scalar "$context_path" "brand" "summary")
    [ -n "$summary" ] || summary="Repository-specific context used to generate a workspace override AGENTS.md and initial STATE.md for $workspace_name."
    printf '%s\n' "$summary"
}

get_derived_error_log_path() {
    context_path="$1"

    error_log_path=$(toml_get_scalar "$context_path" "workspace" "error_log_path")
    [ -n "$error_log_path" ] || error_log_path="ERROR_LOG.md"
    printf '%s\n' "$error_log_path"
}

resolve_workspace_relative_path() {
    workspace_root="$1"
    relative_path="$2"
    path_label="$3"

    if [ -z "$relative_path" ]; then
        printf '%s cannot be empty\n' "$path_label" >&2
        return 1
    fi

    case "$relative_path" in
        /*|~*|[A-Za-z]:*)
            printf '%s must be workspace-relative: %s\n' "$path_label" "$relative_path" >&2
            return 1
            ;;
    esac

    case "$relative_path" in
        */)
            printf '%s cannot end with /: %s\n' "$path_label" "$relative_path" >&2
            return 1
            ;;
    esac

    leaf=$(basename -- "$relative_path")
    case "$leaf" in
        .|..)
            printf '%s must point to a file: %s\n' "$path_label" "$relative_path" >&2
            return 1
            ;;
    esac

    root=$(CDPATH= cd -- "$workspace_root" && pwd)

    IFS=/ read -r -a path_parts <<< "$relative_path"
    resolved_parts=()
    for part in "${path_parts[@]}"; do

        case "$part" in
            ''|.)
                continue
                ;;
            ..)
                if [ "${#resolved_parts[@]}" -eq 0 ]; then
                    printf '%s escapes workspace root: %s\n' "$path_label" "$relative_path" >&2
                    return 1
                fi
                resolved_parts=("${resolved_parts[@]:0:${#resolved_parts[@]}-1}")
                ;;
            *)
                resolved_parts+=("$part")
                ;;
        esac
    done

    if [ "${#resolved_parts[@]}" -eq 0 ]; then
        printf '%s must point to a file: %s\n' "$path_label" "$relative_path" >&2
        return 1
    fi

    resolved_path=$(printf '%s' "${resolved_parts[0]}")
    idx=1
    while [ "$idx" -lt "${#resolved_parts[@]}" ]; do
        resolved_path="${resolved_path}/${resolved_parts[$idx]}"
        idx=$((idx + 1))
    done

    printf '%s\n' "$root/$resolved_path"
}

get_derived_repository_facts() {
    context_path="$1"

    load_context_array repository_facts "$context_path" "repository" "facts"
    display_name=$(toml_get_scalar "$context_path" "workspace" "display_name")
    page_kind=$(toml_get_scalar "$context_path" "workspace" "page_kind")
    primary_entry=$(toml_get_scalar "$context_path" "workspace" "primary_entry")
    page_url=$(toml_get_scalar "$context_path" "workspace" "page_url")
    locale=$(toml_get_scalar "$context_path" "workspace" "locale")
    error_log_path=$(get_derived_error_log_path "$context_path")
    source_of_truth=$(toml_get_scalar "$context_path" "architecture" "source_of_truth")
    shell_runtime=$(toml_get_scalar "$context_path" "architecture" "shell_runtime")
    shared_react=$(toml_get_scalar "$context_path" "architecture" "shared_react_components")
    authoring_model=$(toml_get_scalar "$context_path" "workflow" "authoring_model")
    working_style=$(toml_get_scalar "$context_path" "workflow" "current_working_style")
    deploy_goal=$(toml_get_scalar "$context_path" "deployment_goal" "primary_runtime")
    current_deploy_base=$(toml_get_scalar "$context_path" "deployment_current" "active_deploy_base")

    merge_context_items \
        ${repository_facts[@]+"${repository_facts[@]}"} \
        "${display_name:+Display name: $display_name}" \
        "${page_kind:+Page kind: $page_kind}" \
        "${primary_entry:+Primary entry: $primary_entry}" \
        "${page_url:+Primary page URL: $page_url}" \
        "${locale:+Locale: $locale}" \
        "${error_log_path:+Error log path: \`$error_log_path\`}" \
        "${source_of_truth:+Source of truth: $source_of_truth}" \
        "${shell_runtime:+Shell runtime: $shell_runtime}" \
        "${shared_react:+Shared React components: $shared_react}" \
        "${authoring_model:+Authoring model: $authoring_model}" \
        "${working_style:+Working style: $working_style}" \
        "${deploy_goal:+Deployment goal: $deploy_goal}" \
        "${current_deploy_base:+Current deployment base: $current_deploy_base}"
}

get_derived_verification_commands() {
    context_path="$1"
    load_context_array commands_a "$context_path" "verification" "commands"
    load_context_array commands_b "$context_path" "verification" "recommended_commands"
    merge_context_items ${commands_a[@]+"${commands_a[@]}"} ${commands_b[@]+"${commands_b[@]}"}
}

get_derived_shared_contracts() {
    context_path="$1"
    load_context_array contracts_shared "$context_path" "contracts" "shared"
    source_of_truth=$(toml_get_scalar "$context_path" "architecture" "source_of_truth")
    route_constants=$(toml_get_scalar "$context_path" "architecture" "route_constants")
    authoring_model=$(toml_get_scalar "$context_path" "workflow" "authoring_model")
    mirror_policy=$(toml_get_scalar "$context_path" "deployment_target" "mirror_policy")
    env_source=$(toml_get_scalar "$context_path" "env_strategy" "current_env_source_of_truth")

    merge_context_items \
        ${contracts_shared[@]+"${contracts_shared[@]}"} \
        "${source_of_truth:+Frontend source of truth remains $source_of_truth}" \
        "${route_constants:+Route constants stay aligned with $route_constants}" \
        "${authoring_model:+$authoring_model}" \
        "${mirror_policy:+$mirror_policy}" \
        "${env_source:+Current env source of truth: $env_source}"
}

get_derived_shared_asset_paths() {
    context_path="$1"
    load_context_array shared_assets_a "$context_path" "paths" "shared_assets"
    load_context_array shared_assets_b "$context_path" "editing_rules" "edit_in"
    shell_runtime=$(toml_get_scalar "$context_path" "architecture" "shell_runtime")
    shared_react=$(toml_get_scalar "$context_path" "architecture" "shared_react_components")
    landing_script=$(toml_get_scalar "$context_path" "architecture" "landing_script")
    landing_stylesheet=$(toml_get_scalar "$context_path" "architecture" "landing_stylesheet")
    header_component=$(toml_get_scalar "$context_path" "architecture" "header_component")
    footer_component=$(toml_get_scalar "$context_path" "architecture" "footer_component")
    route_constants=$(toml_get_scalar "$context_path" "architecture" "route_constants")

    if [ "${#shared_assets_a[@]}" -gt 0 ]; then
        compress_path_like_items ${shared_assets_a[@]+"${shared_assets_a[@]}"}
        return
    fi

    if [ "${#shared_assets_b[@]}" -gt 0 ]; then
        compress_path_like_items ${shared_assets_b[@]+"${shared_assets_b[@]}"}
        return
    fi

    compress_path_like_items \
        "$shell_runtime" \
        "$shared_react" \
        "$landing_script" \
        "$landing_stylesheet" \
        "$header_component" \
        "$footer_component" \
        "$route_constants"
}

get_derived_do_not_touch_paths() {
    context_path="$1"
    load_context_array do_not_touch_a "$context_path" "paths" "do_not_touch"
    load_context_array do_not_touch_b "$context_path" "editing_rules" "do_not_edit"
    if [ "${#do_not_touch_b[@]}" -gt 0 ]; then
        compress_path_like_items ${do_not_touch_b[@]+"${do_not_touch_b[@]}"}
        return
    fi

    compress_path_like_items ${do_not_touch_a[@]+"${do_not_touch_a[@]}"}
}

get_derived_hard_triggers() {
    context_path="$1"
    load_context_array hard_triggers_a "$context_path" "triggers" "hard"
    route_constants=$(toml_get_scalar "$context_path" "architecture" "route_constants")
    shell_runtime=$(toml_get_scalar "$context_path" "architecture" "shell_runtime")
    webapp_mirror=$(toml_get_scalar "$context_path" "architecture" "webapp_mirror")
    spring_mirror=$(toml_get_scalar "$context_path" "architecture" "spring_mirror")

    merge_context_items \
        ${hard_triggers_a[@]+"${hard_triggers_a[@]}"} \
        "${route_constants:+Changing route constants or route ownership in $route_constants}" \
        "${shell_runtime:+Changing shared shell runtime behavior in $shell_runtime}" \
        "${webapp_mirror:+Touching deployment mirror path $webapp_mirror}" \
        "${spring_mirror:+Touching deployment mirror path $spring_mirror}"
}

get_derived_approval_zones() {
    context_path="$1"
    load_context_array approval_a "$context_path" "approval" "zones"
    if [ "${#approval_a[@]}" -gt 0 ]; then
        merge_context_items ${approval_a[@]+"${approval_a[@]}"}
        return
    fi

    deploy_method=$(toml_get_scalar "$context_path" "deployment_current" "deploy_method")
    deploy_target=$(toml_get_scalar "$context_path" "deployment_current" "deploy_target")
    execution_mode=$(toml_get_scalar "$context_path" "deployment_target" "final_execution_mode")
    [ -n "$execution_mode" ] || execution_mode=$(toml_get_scalar "$context_path" "deployment_goal" "target_execution_mode")
    target_platform=$(toml_get_scalar "$context_path" "deployment_goal" "target_platform")
    oracle_priority=$(toml_get_scalar "$context_path" "deployment_goal" "oracle_cloud_priority")
    future_plan=$(toml_get_scalar "$context_path" "env_strategy" "future_plan")

    merge_context_items \
        ${approval_a[@]+"${approval_a[@]}"} \
        "${deploy_method:+Deployment method changes: $deploy_method}" \
        "${deploy_target:+Deploy target changes: $deploy_target}" \
        "${execution_mode:+Execution mode changes: $execution_mode}" \
        "${target_platform:+Target platform changes: $target_platform}" \
        "${oracle_priority:+Oracle Cloud rollout changes: $oracle_priority}" \
        "${future_plan:+Runtime env ownership changes: $future_plan}"
}

get_derived_worker_mapping() {
    context_path="$1"
    load_context_array worker_mapping_a "$context_path" "workers" "mapping"
    if [ "${#worker_mapping_a[@]}" -gt 0 ]; then
        merge_context_items ${worker_mapping_a[@]+"${worker_mapping_a[@]}"}
        return
    fi

    shell_runtime=$(toml_get_scalar "$context_path" "architecture" "shell_runtime")
    shared_react=$(toml_get_scalar "$context_path" "architecture" "shared_react_components")
    route_constants=$(toml_get_scalar "$context_path" "architecture" "route_constants")
    header_component=$(toml_get_scalar "$context_path" "architecture" "header_component")
    footer_component=$(toml_get_scalar "$context_path" "architecture" "footer_component")
    landing_script=$(toml_get_scalar "$context_path" "architecture" "landing_script")
    landing_stylesheet=$(toml_get_scalar "$context_path" "architecture" "landing_stylesheet")
    primary_entry=$(toml_get_scalar "$context_path" "workspace" "primary_entry")

    shell_scope=()
    [ -n "$shell_runtime" ] && shell_scope+=("$shell_runtime")
    [ -n "$route_constants" ] && shell_scope+=("$route_constants")

    shared_scope=()
    [ -n "$shared_react" ] && shared_scope+=("$shared_react")
    [ -n "$header_component" ] && shared_scope+=("$header_component")
    [ -n "$footer_component" ] && shared_scope+=("$footer_component")

    landing_scope=()
    [ -n "$primary_entry" ] && landing_scope+=("$primary_entry")
    [ -n "$landing_script" ] && landing_scope+=("$landing_script")
    [ -n "$landing_stylesheet" ] && landing_scope+=("$landing_stylesheet")

    merge_context_items \
        ${worker_mapping_a[@]+"${worker_mapping_a[@]}"} \
        "$([ "${#shell_scope[@]}" -gt 0 ] && printf 'worker_shell_runtime = %s' "$(merge_context_items ${shell_scope[@]+"${shell_scope[@]}"} | paste -sd ', ' -)")" \
        "$([ "${#shared_scope[@]}" -gt 0 ] && printf 'worker_shared = %s' "$(merge_context_items ${shared_scope[@]+"${shared_scope[@]}"} | paste -sd ', ' -)")" \
        "$([ "${#landing_scope[@]}" -gt 0 ] && printf 'worker_feature_landing = %s' "$(merge_context_items ${landing_scope[@]+"${landing_scope[@]}"} | paste -sd ', ' -)")"
}

get_derived_reviewer_focus() {
    context_path="$1"
    load_context_array reviewer_focus_a "$context_path" "reviewer" "focus"
    if [ "${#reviewer_focus_a[@]}" -gt 0 ]; then
        merge_context_items ${reviewer_focus_a[@]+"${reviewer_focus_a[@]}"}
        return
    fi

    load_context_array reviewer_focus_b "$context_path" "editing_rules" "notes"
    merge_context_items ${reviewer_focus_b[@]+"${reviewer_focus_b[@]}"}
}

get_derived_forbidden_patterns() {
    context_path="$1"
    load_context_array forbidden_a "$context_path" "forbidden" "patterns"
    load_context_array forbidden_b "$context_path" "content_guidelines" "avoid"
    merge_context_items ${forbidden_a[@]+"${forbidden_a[@]}"} ${forbidden_b[@]+"${forbidden_b[@]}"}
}

generate_workspace_agents_from_context() {
    context_path="$1"
    workspace_name="$2"
    template_name="$3"
    agents_target="$4"
    workspace_root=$(dirname "$agents_target")

    title=$(toml_get_scalar "$context_path" "workspace" "name")
    summary=$(get_derived_workspace_summary "$context_path" "$workspace_name")
    task_board_path=$(toml_get_scalar "$context_path" "workspace" "task_board_path")
    multi_agent_log_path=$(toml_get_scalar "$context_path" "workspace" "multi_agent_log_path")
    error_log_path=$(get_derived_error_log_path "$context_path")

    [ -n "$title" ] || title="$workspace_name"
    [ -n "$task_board_path" ] || task_board_path="STATE.md"
    [ -n "$multi_agent_log_path" ] || multi_agent_log_path="MULTI_AGENT_LOG.md"
    resolve_workspace_relative_path "$workspace_root" "$task_board_path" "task_board_path" >/dev/null
    resolve_workspace_relative_path "$workspace_root" "$error_log_path" "error_log_path" >/dev/null

    load_array_from_command repository_facts get_derived_repository_facts "$context_path"
    load_context_array required_read "$context_path" "required_context" "read"
    load_array_from_command verification_commands get_derived_verification_commands "$context_path"
    load_array_from_command shared_contracts get_derived_shared_contracts "$context_path"
    load_array_from_command shared_asset_paths get_derived_shared_asset_paths "$context_path"
    load_array_from_command do_not_touch_paths get_derived_do_not_touch_paths "$context_path"
    load_array_from_command hard_triggers get_derived_hard_triggers "$context_path"
    load_array_from_command approval_zones get_derived_approval_zones "$context_path"
    load_array_from_command worker_mapping get_derived_worker_mapping "$context_path"
    load_array_from_command reviewer_focus get_derived_reviewer_focus "$context_path"
    load_array_from_command forbidden_patterns get_derived_forbidden_patterns "$context_path"

    {
        printf '# Workspace Override: %s\n\n' "$title"
        if [ -n "$summary" ]; then
            printf '%s\n\n' "$summary"
        fi
        printf 'This file adds repository-specific rules on top of the global multi-agent defaults.\n'
        printf 'Global multi-agent defaults remain in effect unless this file narrows them.\n'

        combined_facts=(${repository_facts[@]+"${repository_facts[@]}"} "Task board path: \`$task_board_path\`" "Multi-agent log path: \`$multi_agent_log_path\`" "Error log path: \`$error_log_path\`")
        write_markdown_section 'Repository Facts' ${combined_facts[@]+"${combined_facts[@]}"}
        write_markdown_section 'Required Context Before Editing' ${required_read[@]+"${required_read[@]}"}
        write_markdown_section 'Verification Commands' ${verification_commands[@]+"${verification_commands[@]}"}
        write_markdown_section 'Shared Contracts' ${shared_contracts[@]+"${shared_contracts[@]}"}
        write_markdown_section 'Shared Asset Paths' ${shared_asset_paths[@]+"${shared_asset_paths[@]}"}
        write_markdown_section 'Repo-Specific Hard Triggers' ${hard_triggers[@]+"${hard_triggers[@]}"}
        write_markdown_section 'Do-Not-Touch Paths' ${do_not_touch_paths[@]+"${do_not_touch_paths[@]}"}
        write_markdown_section 'Manual Approval Zones' ${approval_zones[@]+"${approval_zones[@]}"}
        write_markdown_section 'Worker Mapping' ${worker_mapping[@]+"${worker_mapping[@]}"}

        printf '\n## Repository Overrides\n\n'
        printf -- '- Role caps inherited from global defaults stay fixed\n'
        printf '  `explorer 3`, `reviewer 2`, `worker up to 4 on Route B`\n'
    printf -- '- Keep `%s` updated with exact `route`, concrete `reason`, `owned_write_sets`, and `contract_freeze` when Route B is active; use `writer_scope` and `worker_ownership_map` in the Writer Slot section\n' "$task_board_path"
        printf -- '- If multiple roles are used, append real participation to `%s` before reporting that they ran\n' "$multi_agent_log_path"
        if [ "$template_name" = "minimal" ]; then
            printf -- '- Keep changes small\n'
            printf -- '- Let this repository narrow Route A/B behavior further only when it truly needs stricter local rules\n'
        else
            printf -- '- Add repository-specific worker ownership, hard triggers, and approval zones here as they become clear\n'
            printf -- '- Let this repository narrow Route A/B behavior further only when it truly needs stricter local rules\n'
        fi

        write_markdown_section 'Reviewer Focus' ${reviewer_focus[@]+"${reviewer_focus[@]}"}
        write_markdown_section 'Forbidden Patterns' ${forbidden_patterns[@]+"${forbidden_patterns[@]}"}
    } > "$agents_target"
}

generate_workspace_state_from_context() {
    context_path="$1"
    workspace_name="$2"
    state_target="$3"

    title=$(toml_get_scalar "$context_path" "workspace" "name")
    [ -n "$title" ] || title="$workspace_name"

    {
        printf '# STATE\n\n'
        printf '## Current Task\n\n'
        printf -- '- active_tasks: `n/a`\n'
        printf -- '- blocked_tasks: `n/a`\n'
        printf -- '- owned_write_sets: `n/a`\n'
        printf -- '- task_state_dir: `state/`\n'
        printf -- '- status_overview: `n/a`\n'
        printf -- '- note: `Use root STATE.md for board-level ownership and summaries. Put per-thread detail in state/TASK-*.md files.`\n'
        printf '\n## Route\n\n'
        printf -- '- route: `Route A`\n'
        printf -- '- reason: `placeholder - classify the first task as Route A or Route B before editing`\n'
        printf '\n## Writer Slot\n\n'
        printf -- '- owner: `main`\n'
    printf -- '- writer_scope: `n/a`\n'
    printf -- '- worker_ownership_map:\n'
    printf '  - `main`: `n/a`\n'
    printf '  - `worker`: `n/a`\n'
    printf '  - `reviewer`: `n/a`\n'
    printf -- '- note: `Use owned_write_sets for the root board; use writer_scope and worker_ownership_map for this section. Route A has no subagents or reviewer calls; Route B is delegated with worker and reviewer roles.`\n'
        printf '\n## Contract Freeze\n\n'
        printf -- '- contract_freeze: `n/a`\n'
        printf '\n## Seed\n\n'
        printf -- '- status: `n/a`\n'
        printf -- '- path: `n/a`\n'
        printf -- '- revision: `n/a`\n'
        printf -- '- note: `Use this section to track the active frozen seed once a spec-first task starts.`\n'
        printf '\n## Reviewer\n\n'
        printf -- '- reviewer: `n/a`\n'
        printf -- '- reviewer_target: `n/a`\n'
        printf -- '- reviewer_focus: `n/a`\n'
        printf '\n## Last Update\n\n'
        printf -- '- timestamp: `[timestamp]`\n'
        printf -- '- note: `Template generated by installer.`\n'
    } > "$state_target"
}

should_overwrite_file() {
    path="$1"

    if [ ! -e "$path" ]; then
        return 0
    fi

    if [ "$FORCE" -eq 1 ] || [ "$NO_PROMPT" -eq 1 ]; then
        return 0
    fi

    while true; do
        printf 'Overwrite existing file %s ? [Y/N] ' "$path"
        read -r choice
        case "$(printf '%s' "$choice" | tr '[:lower:]' '[:upper:]')" in
            Y) return 0 ;;
            N) return 1 ;;
            *) printf 'Please choose Y or N\n' ;;
        esac
    done
}

install_codex_custom_agents() {
    source_kit_root="$1"
    backup_root="$2"
    source_agents_root="${source_kit_root}/codex_agents"

    if [ ! -d "$source_agents_root" ]; then
        return
    fi

    ensure_directory "$GLOBAL_CUSTOM_AGENTS_ROOT"
    backup_path_if_exists "$GLOBAL_CUSTOM_AGENTS_ROOT" "$backup_root" "agents"

    while IFS= read -r -d '' existing_file; do
        [ -f "$existing_file" ] || continue
        [ -L "$existing_file" ] && continue
        base_name=$(basename "$existing_file")
        keep=0
        for managed in "${MANAGED_AGENT_FILES[@]}"; do
            if [ "$base_name" = "$managed" ]; then
                keep=1
                break
            fi
        done
        if [ "$keep" -eq 0 ]; then
            rm -f "$existing_file"
        fi
    done < <(iter_top_level_sorted_paths "$GLOBAL_CUSTOM_AGENTS_ROOT" file)

    while IFS= read -r -d '' source_file; do
        [ -f "$source_file" ] || continue
        [ -L "$source_file" ] && continue
        target="${GLOBAL_CUSTOM_AGENTS_ROOT}/$(basename "$source_file")"
        cp "$source_file" "$target"
    done < <(iter_top_level_sorted_paths "$source_agents_root" file)
}

install_codex_skills() {
    source_kit_root="$1"
    backup_root="$2"
    source_skills_root="${source_kit_root}/codex_skills"

    if [ ! -d "$source_skills_root" ]; then
        return
    fi

    ensure_directory "$GLOBAL_SKILLS_ROOT"
    backup_path_if_exists "$GLOBAL_SKILLS_ROOT" "$backup_root" "skills"
    backup_path_if_exists "$GLOBAL_MANAGED_SKILLS_MANIFEST" "$backup_root" "installer-managed-skills.manifest"

    tmp_manifest=$(mktemp)
    : > "$tmp_manifest"

    while IFS= read -r -d '' source_skill_dir; do
        [ -d "$source_skill_dir" ] || continue
        managed_skill_name=$(basename "$source_skill_dir")
        printf '%s\n' "$managed_skill_name" >> "$tmp_manifest"
        copy_directory_contents "$source_skill_dir" "${GLOBAL_SKILLS_ROOT}/${managed_skill_name}"
    done < <(iter_top_level_sorted_paths "$source_skills_root" dir)

    if [ -f "$GLOBAL_MANAGED_SKILLS_MANIFEST" ]; then
        while IFS= read -r managed_skill_name; do
            [ -n "$managed_skill_name" ] || continue
            if ! grep -Fxq "$managed_skill_name" "$tmp_manifest"; then
                rm -rf "${GLOBAL_SKILLS_ROOT}/${managed_skill_name}"
            fi
        done < "$GLOBAL_MANAGED_SKILLS_MANIFEST"
    fi

    mv "$tmp_manifest" "$GLOBAL_MANAGED_SKILLS_MANIFEST"
}

install_codex_rules() {
    source_kit_root="$1"
    source_rules_root="${source_kit_root}/codex_rules"

    if [ ! -d "$source_rules_root" ]; then
        return
    fi

    ensure_directory "$GLOBAL_RULES_ROOT"

    while IFS= read -r -d '' source_file; do
        [ -f "$source_file" ] || continue
        [ -L "$source_file" ] && continue
        target="${GLOBAL_RULES_ROOT}/$(basename "$source_file")"

        if should_overwrite_file "$target"; then
            cp "$source_file" "$target"
        else
            printf 'Skipped rules overwrite: %s\n' "$target"
        fi
    done < <(iter_top_level_sorted_paths "$source_rules_root" file)
}

ensure_config_array_contains() {
    file="$1"
    key="$2"
    shift 2

    tmp_file=$(mktemp)
    if [ -f "$file" ]; then
        awk -v key="$key" -v values="$(printf '%s\n' "$@" | paste -sd '\t' -)" '
            BEGIN {
                split(values, required, "\t")
            }
            function trim(s) {
                sub(/^[[:space:]]+/, "", s)
                sub(/[[:space:]]+$/, "", s)
                return s
            }
            {
                if ($0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
                    found = 1
                    current = $0
                    sub(/^[^[]*\[/, "", current)
                    sub(/\].*$/, "", current)
                    n = split(current, raw, ",")
                    count = 0
                    for (i in required) {
                        item = required[i]
                        if (item != "" && !seen[item]++) {
                            ordered[++count] = item
                        }
                    }
                    for (i = 1; i <= n; i++) {
                        item = trim(raw[i])
                        gsub(/^"/, "", item)
                        gsub(/"$/, "", item)
                        if (item != "" && !seen[item]++) {
                            ordered[++count] = item
                        }
                    }
                    printf "%s = [", key
                    for (i = 1; i <= count; i++) {
                        printf "%s\"%s\"", (i > 1 ? ", " : ""), ordered[i]
                    }
                    print "]"
                    next
                }
                print
            }
            END {
                if (!found) {
                    printf "%s = [", key
                    count = 0
                    for (i in required) {
                        item = required[i]
                        if (item != "" && !seen[item]++) {
                            ordered[++count] = item
                        }
                    }
                    for (i = 1; i <= count; i++) {
                        printf "%s\"%s\"", (i > 1 ? ", " : ""), ordered[i]
                    }
                    print "]"
                }
            }
        ' "$file" > "$tmp_file"
    else
        {
            printf '# Codex Configuration\n\n'
            printf '%s = [' "$key"
            idx=0
            for item in "$@"; do
                if [ -n "$item" ]; then
                    idx=$((idx + 1))
                    [ "$idx" -gt 1 ] && printf ', '
                    printf '"%s"' "$item"
                fi
            done
            printf ']\n'
        } > "$tmp_file"
    fi
    mv "$tmp_file" "$file"
}

ensure_config_section_key_value() {
    file="$1"
    section="$2"
    key="$3"
    value="$4"

    tmp_file=$(mktemp)
    if [ -f "$file" ]; then
        awk -v section="$section" -v key="$key" -v value="$value" '
            function trim(s) {
                sub(/^[[:space:]]+/, "", s)
                sub(/[[:space:]]+$/, "", s)
                return s
            }
            {
                line = $0
                trimmed = trim(line)
                if (trimmed == "[" section "]") {
                    in_section = 1
                    section_found = 1
                    print line
                    next
                }
                if (in_section && trimmed ~ /^\[.*\]$/) {
                    if (!key_found) {
                        print key " = " value
                        key_found = 1
                    }
                    in_section = 0
                }
                if (in_section && trimmed ~ ("^" key "[[:space:]]*=")) {
                    print key " = " value
                    key_found = 1
                    next
                }
                print line
            }
            END {
                if (in_section && !key_found) {
                    print key " = " value
                } else if (!section_found) {
                    if (NR > 0) {
                        print ""
                    }
                    print "[" section "]"
                    print key " = " value
                }
            }
        ' "$file" > "$tmp_file"
    else
        {
            printf '# Codex Configuration\n\n'
            printf '[%s]\n' "$section"
            printf '%s = %s\n' "$key" "$value"
        } > "$tmp_file"
    fi
    mv "$tmp_file" "$file"
}

get_config_developer_instructions() {
    cat <<'EOF'
Use subagents proactively when the route permits it and doing so improves focus, speed, or result quality.

Execution requirements:
- Always load and follow the nearest applicable AGENTS.md before implementation.
- Prefer workspace AGENTS.md over global AGENTS.md when both exist.
- Treat AGENTS.md as the source of truth for route selection, delegation, state updates, and verification flow.
- On each new user request, compare it against the root task registry in STATE.md and any relevant `state/TASK-*.md` files before continuing, even if the work looks like a continuation of the same feature.
- Start new tasks from `state/TASK_TEMPLATE.md` instead of stuffing detail back into root STATE.md.
- Do not continue implementation from an existing STATE.md unless the request clearly matches the same board entry and task-state file.
- Treat investigation, planning, and implementation as separate stages.
- If read-only investigation or planning turns into implementation, re-check the route, update STATE.md, and explicitly enter implementation before writing.
- Before parallelizing larger tasks, freeze the contract and write sets first.

Error logging:
- Leave interrupted or paused errors in ERROR_LOG.md as open or deferred until a later append marks them resolved.

Default behavior:
- For read-heavy or parallelizable work such as codebase exploration, reviews, tracing execution paths, log analysis, test-failure triage, and multi-part research, delegate to built-in subagents without waiting for the user to say "spawn" or "parallelize".
- Close finished agents promptly once their output is consumed.
- Prefer spawning reviewers as late as practical unless earlier review is explicitly needed.
- Prefer `explorer` for read-only investigation, `worker` for bounded implementation after scope is clear, and `reviewer` for read-only close-out checks.
- Keep the main thread focused on requirements, decisions, synthesis, route selection, and final answers.
- Assume the user permits normal subagent use in this workspace; the main thread applies the AGENTS.md route result rather than re-deciding whether spawning is desirable.

Spawn requirements:
- These spawn settings are mandatory. Do not rely on inherited defaults, implicit role defaults, or absent custom agent files.
- Every explorer-style spawn_agent call must explicitly set model = "gpt-5.4-mini" and reasoning_effort = "medium".
- Every worker-style spawn_agent call must explicitly set model = "gpt-5.4-mini" and reasoning_effort = "medium".
- Every reviewer-style spawn_agent call must explicitly set model = "gpt-5.4-mini" and reasoning_effort = "high".
- Do not use `fork_context` unless exact thread context is required.
- Do not substitute other models or lower reasoning effort unless the user explicitly overrides this in the current conversation.
- If a planned spawn does not match these requirements, correct the parameters before calling spawn_agent.

Delegation rules:
- On Route A, stay in one write-capable lane and spawn no subagents or reviewer calls.
- On Route B, keep main planner-only and always spawn at least one worker plus one reviewer.
- Assign exactly one write set to each worker.
- Promote Route A to Route B when work extracts a shared component, replaces page-specific implementations with a shared renderer, or unifies 2+ pages onto one shared implementation.
- On Route B, keep main planner-only and always spawn at least one worker plus one reviewer.
- Do not close Route B without the required reviewer pass.
- Do not skip route or reason logging when AGENTS.md requires it.
- Do not open browsers or inspect external domains unless AGENTS.md permits it or the user explicitly asks for it.

Execution bias:
- Assume you are allowed to use subagents when the task matches the patterns above.
EOF
}

ensure_config_top_level_multiline_value() {
    file="$1"
    key="$2"
    temp_file=$(mktemp)

    if [ -f "$file" ]; then
        awk -v key="$key" '
            BEGIN { skip = 0 }
            {
                trimmed = $0
                sub(/^[[:space:]]+/, "", trimmed)

                if (!skip && trimmed ~ ("^" key "[[:space:]]*=")) {
                    if (trimmed ~ /"""/ && gsub(/"""/, "&", trimmed) == 1) {
                        skip = 1
                    }
                    next
                }

                if (skip) {
                    if (trimmed ~ /^"""[[:space:]]*$/) {
                        skip = 0
                    }
                    next
                }

                print $0
            }
        ' "$file" > "$temp_file"
    else
        : > "$temp_file"
    fi

    content_file=$(mktemp)
    get_config_developer_instructions > "$content_file"

    output_file=$(mktemp)
    inserted=0
    {
        while IFS= read -r line || [ -n "$line" ]; do
            trimmed="$line"
            trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
            if [ "$inserted" -eq 0 ] && [[ "$trimmed" == \[*\] ]]; then
                printf '%s = """\n' "$key"
                cat "$content_file"
                printf '"""\n\n'
                inserted=1
            fi
            printf '%s\n' "$line"
        done < "$temp_file"

        if [ "$inserted" -eq 0 ]; then
            printf '%s = """\n' "$key"
            cat "$content_file"
            printf '"""\n'
        fi
    } > "$output_file"

    mv "$output_file" "$file"
    rm -f "$temp_file" "$content_file"
}

remove_legacy_config_agent_sections() {
    file="$1"
    shift
    tmp_file=$(mktemp)
    if [ ! -f "$file" ]; then
        return
    fi
    awk -v allowed="$(printf '%s\n' "$@" | paste -sd '\t' -)" '
        BEGIN {
            split(allowed, items, "\t")
            for (i in items) {
                keep[items[i]] = 1
            }
        }
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        {
            trimmed = trim($0)
            if (trimmed ~ /^\[agents\.[^]]+\]$/) {
                section_name = trimmed
                sub(/^\[agents\./, "", section_name)
                sub(/\]$/, "", section_name)
                skip = !keep[section_name]
            } else if (trimmed ~ /^\[.*\]$/) {
                skip = 0
            }
            if (!skip) {
                print $0
            }
        }
    ' "$file" > "$tmp_file"
    mv "$tmp_file" "$file"
}

install_codex_config() {
    backup_root="$1"
    ensure_directory "$(dirname "$GLOBAL_CONFIG_PATH")"
    backup_path_if_exists "$GLOBAL_CONFIG_PATH" "$backup_root" "config.toml"
    remove_legacy_config_agent_sections "$GLOBAL_CONFIG_PATH" "default" "worker" "explorer" "reviewer"
    ensure_config_array_contains "$GLOBAL_CONFIG_PATH" "project_doc_fallback_filenames" "AGENTS.md"
    ensure_config_top_level_multiline_value "$GLOBAL_CONFIG_PATH" "developer_instructions"
    ensure_config_section_key_value "$GLOBAL_CONFIG_PATH" "features" "multi_agent" "true"
    ensure_config_section_key_value "$GLOBAL_CONFIG_PATH" "agents.default" "config_file" "\"./agents/default.toml\""
    ensure_config_section_key_value "$GLOBAL_CONFIG_PATH" "agents.worker" "config_file" "\"./agents/worker.toml\""
    ensure_config_section_key_value "$GLOBAL_CONFIG_PATH" "agents.explorer" "config_file" "\"./agents/explorer.toml\""
    ensure_config_section_key_value "$GLOBAL_CONFIG_PATH" "agents.reviewer" "config_file" "\"./agents/reviewer.toml\""
}

show_info_banner() {
    source_root=$(get_source_kit_root)
    if [ "$source_root" = "$GLOBAL_KIT_ROOT" ]; then
        source_label='global kit'
    else
        source_label='local repository copy'
    fi

    write_section 'Codex Multi-Agent Kit'
    printf 'Source: %s\n' "$source_label"
    printf 'Local path: %s\n' "$LOCAL_KIT_ROOT"
    printf 'Global home: %s\n' "$GLOBAL_HOME"
    printf 'Global defaults: %s\n' "$GLOBAL_AGENTS_PATH"
}

select_folder() {
    description="$1"

    if [ "$NO_PROMPT" -eq 1 ]; then
        printf 'A target folder is required when --no-prompt is used\n' >&2
        exit 1
    fi

    printf '%s\n' "$description"
    printf 'Enter a full path: '
    read -r path

    if [ -z "$path" ]; then
        printf 'No folder selected\n' >&2
        exit 1
    fi

    printf '%s\n' "$path"
}

read_menu_choice() {
    if [ "$NO_PROMPT" -eq 1 ]; then
        printf 'Mode=Menu cannot be used with --no-prompt\n' >&2
        exit 1
    fi

    printf '\nChoose a mode\n'
    printf '[1] Install global defaults for all Codex workspaces\n'
    printf '[2] Apply a workspace override\n'
    printf '[Q] Quit\n'

    while true; do
        printf 'Selection: '
        read -r choice
        case "$(printf '%s' "$choice" | tr '[:lower:]' '[:upper:]')" in
            1) printf 'InstallGlobal\n'; return ;;
            2) printf 'ApplyWorkspace\n'; return ;;
            Q) printf 'Quit\n'; return ;;
            *) printf 'Please choose 1, 2, or Q\n' ;;
        esac
    done
}

read_template_choice() {
    if [ "$NO_PROMPT" -eq 1 ]; then
        printf '%s\n' "$TEMPLATE"
        return
    fi

    printf '\nChoose a workspace override template\n'
    printf '[1] Standard\n'
    printf '[2] Minimal\n'

    while true; do
        printf 'Selection: '
        read -r choice
        case "$choice" in
            1) printf 'standard\n'; return ;;
            2) printf 'minimal\n'; return ;;
            *) printf 'Please choose 1 or 2\n' ;;
        esac
    done
}

read_include_docs_choice() {
    if [ "$NO_PROMPT" -eq 1 ]; then
        printf '%s\n' "$INCLUDE_DOCS"
        return
    fi

    printf '\nCopy supporting docs to docs/codex-multiagent\n'
    printf '[Y] Yes\n'
    printf '[N] No\n'

    while true; do
        printf 'Selection: '
        read -r choice
        case "$(printf '%s' "$choice" | tr '[:lower:]' '[:upper:]')" in
            Y) printf '1\n'; return ;;
            N) printf '0\n'; return ;;
            *) printf 'Please choose Y or N\n' ;;
        esac
    done
}

install_global_kit() {
    write_section 'Installing global defaults'

    ensure_directory "$GLOBAL_HOME"
    ensure_directory "$GLOBAL_KIT_ROOT"
    remove_stale_installer_artifacts "${GLOBAL_KIT_ROOT}/installer"
    backup_root="${GLOBAL_HOME}/backups/$(get_backup_stamp)/global"
    backup_path_if_exists "$GLOBAL_AGENTS_PATH" "$backup_root" "AGENTS.md"

    for item in \
        README.md \
        AGENTS.md \
        WORKSPACE_CONTEXT_TEMPLATE.toml \
        MULTI_AGENT_GUIDE.md \
        CHANGELOG.md \
        codex_agents \
        codex_rules \
        codex_skills \
        docs \
        examples \
        profiles \
        installer
    do
        source="${LOCAL_KIT_ROOT}/${item}"
        destination="${GLOBAL_KIT_ROOT}/${item}"

        if [ -d "$source" ]; then
            copy_directory_contents "$source" "$destination"
        else
            ensure_directory "$(dirname "$destination")"
            cp "$source" "$destination"
        fi
    done

    if ! should_overwrite_file "$GLOBAL_AGENTS_PATH"; then
        printf 'Skipped global AGENTS.md overwrite\n'
    else
        cp "${LOCAL_KIT_ROOT}/AGENTS.md" "$GLOBAL_AGENTS_PATH"
    fi
    install_codex_config "$backup_root"
    install_codex_custom_agents "$LOCAL_KIT_ROOT" "$backup_root"
    install_codex_skills "$LOCAL_KIT_ROOT" "$backup_root"
    install_codex_rules "$LOCAL_KIT_ROOT"

    printf 'Installed global defaults at %s\n' "$GLOBAL_AGENTS_PATH"
    printf 'Patched Codex config at %s\n' "$GLOBAL_CONFIG_PATH"
    printf 'Installed Codex subagent configs at %s\n' "$GLOBAL_CUSTOM_AGENTS_ROOT"
    printf 'Installed Codex command rules at %s\n' "$GLOBAL_RULES_ROOT"
    printf 'Reference kit copied to %s\n' "$GLOBAL_KIT_ROOT"
}

apply_to_workspace() {
    workspace_path="$1"
    template_name="$2"
    copy_docs="$3"

    ensure_directory "$workspace_path"
    resolved_workspace=$(CDPATH= cd -- "$workspace_path" && pwd)
    source_kit_root=$(get_source_kit_root)
    context_path=$(get_workspace_context_path "$resolved_workspace")
    agents_target="${resolved_workspace}/AGENTS.md"
    state_relative_path=$(toml_get_scalar "$context_path" "workspace" "task_board_path")
    [ -n "$state_relative_path" ] || state_relative_path="STATE.md"
    state_target=$(resolve_workspace_relative_path "$resolved_workspace" "$state_relative_path" "task_board_path")
    task_state_relative_path=$(toml_get_scalar "$context_path" "workspace" "task_state_dir")
    [ -n "$task_state_relative_path" ] || task_state_relative_path="state/"
    task_state_target=$(resolve_workspace_relative_path "$resolved_workspace" "$task_state_relative_path" "task_state_dir")
    task_template_target="${task_state_target}/TASK_TEMPLATE.md"
    error_log_relative_path=$(toml_get_scalar "$context_path" "workspace" "error_log_path")
    [ -n "$error_log_relative_path" ] || error_log_relative_path="ERROR_LOG.md"
    error_log_target=$(resolve_workspace_relative_path "$resolved_workspace" "$error_log_relative_path" "error_log_path")
    backup_root="${resolved_workspace}/.codex-backups/$(get_backup_stamp)/workspace"

    write_section 'Applying workspace override'
    printf 'Workspace: %s\n' "$resolved_workspace"
    printf 'Template: %s\n' "$template_name"
    printf 'Supporting docs: %s\n' "$copy_docs"
    if [ -f "$context_path" ]; then
        printf 'Workspace context: %s\n' "$context_path"
    fi

    backup_path_if_exists "$agents_target" "$backup_root" "AGENTS.md"
    backup_path_if_exists "$state_target" "$backup_root" "STATE.md"
    backup_path_if_exists "$task_template_target" "$backup_root" "TASK_TEMPLATE.md"

    if [ -f "$context_path" ]; then
        generate_workspace_agents_from_context "$context_path" "$(basename "$resolved_workspace")" "$template_name" "$agents_target"
    else
        generate_default_workspace_agents "$(basename "$resolved_workspace")" "$template_name" > "$agents_target"
    fi

    ensure_directory "$(dirname "$state_target")"
    ensure_directory "$task_state_target"
    generate_default_task_state_template > "$task_template_target"
    if [ -f "$context_path" ]; then
        generate_workspace_state_from_context "$context_path" "$(basename "$resolved_workspace")" "$state_target"
    else
        generate_default_state "$(basename "$resolved_workspace")" > "$state_target"
    fi

    ensure_directory "$(dirname "$error_log_target")"
    if [ ! -e "$error_log_target" ]; then
        generate_default_error_log > "$error_log_target"
    fi

    if [ "$copy_docs" -eq 1 ]; then
        docs_root="${resolved_workspace}/docs/codex-multiagent"

        ensure_directory "$docs_root"

        cp "${source_kit_root}/README.md" "${docs_root}/README.md"
        cp "${source_kit_root}/CHANGELOG.md" "${docs_root}/CHANGELOG.md"
        cp "${source_kit_root}/MULTI_AGENT_GUIDE.md" "${docs_root}/MULTI_AGENT_GUIDE.md"
        cp "${source_kit_root}/WORKSPACE_CONTEXT_TEMPLATE.toml" "${docs_root}/WORKSPACE_CONTEXT_TEMPLATE.toml"
        cp "${source_kit_root}/docs/WORKSPACE_CONTEXT_GUIDE.md" "${docs_root}/WORKSPACE_CONTEXT_GUIDE.md"

        if [ -d "${source_kit_root}/codex_agents" ]; then
            copy_directory_contents "${source_kit_root}/codex_agents" "${docs_root}/codex_agents"
        fi

        if [ -d "${source_kit_root}/codex_rules" ]; then
            copy_directory_contents "${source_kit_root}/codex_rules" "${docs_root}/codex_rules"
        fi

        if [ -d "${source_kit_root}/codex_skills" ]; then
            copy_directory_contents "${source_kit_root}/codex_skills" "${docs_root}/codex_skills"
        fi

        copy_directory_contents "${source_kit_root}/profiles" "${docs_root}/profiles"
        copy_directory_contents "${source_kit_root}/examples" "${docs_root}/examples"
    fi

    printf 'Applied workspace override to %s\n' "$resolved_workspace"
}

while [ $# -gt 0 ]; do
    case "$1" in
        install-global|InstallGlobal)
            MODE="InstallGlobal"
            ;;
        apply-workspace|ApplyWorkspace)
            MODE="ApplyWorkspace"
            ;;
        menu|Menu)
            MODE="Menu"
            ;;
        --mode)
            shift
            MODE="$1"
            ;;
        --workspace|--target-workspace)
            shift
            TARGET_WORKSPACE="$1"
            ;;
        --template)
            shift
            TEMPLATE="$1"
            ;;
        --include-docs)
            INCLUDE_DOCS=1
            ;;
        --force)
            FORCE=1
            ;;
        --no-prompt)
            NO_PROMPT=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

case "$MODE" in
    InstallGlobal|ApplyWorkspace|Menu)
        ;;
    install-global)
        MODE="InstallGlobal"
        ;;
    apply-workspace)
        MODE="ApplyWorkspace"
        ;;
    menu)
        MODE="Menu"
        ;;
    *)
        printf 'Unsupported mode: %s\n' "$MODE" >&2
        usage
        exit 1
        ;;
esac

case "$TEMPLATE" in
    standard|minimal)
        ;;
    *)
        printf 'Unsupported template: %s\n' "$TEMPLATE" >&2
        exit 1
        ;;
esac

show_info_banner

effective_mode="$MODE"
if [ "$effective_mode" = "Menu" ]; then
    effective_mode=$(read_menu_choice)
fi

if [ "$effective_mode" = "Quit" ]; then
    printf 'No action selected\n'
    exit 0
fi

case "$effective_mode" in
    InstallGlobal)
        install_global_kit
        ;;
    ApplyWorkspace)
        effective_template=$(read_template_choice)
        copy_docs=$(read_include_docs_choice)
        if [ -n "$TARGET_WORKSPACE" ]; then
            workspace="$TARGET_WORKSPACE"
        else
            workspace=$(select_folder 'Select the workspace folder for the override')
        fi
        apply_to_workspace "$workspace" "$effective_template" "$copy_docs"
        ;;
    *)
        printf 'Unsupported mode: %s\n' "$effective_mode" >&2
        if [ "$NO_PROMPT" -eq 0 ]; then
            printf 'Reference: %s\n' "$LOCAL_README"
        fi
        exit 1
        ;;
esac
