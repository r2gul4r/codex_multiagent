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
GLOBAL_CUSTOM_AGENTS_ROOT="${GLOBAL_HOME}/agents"
GLOBAL_RULES_ROOT="${GLOBAL_HOME}/rules"
LOCAL_README="${LOCAL_KIT_ROOT}/README.md"

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

remove_stale_installer_artifacts() {
    installer_path="$1"

    rm -rf \
        "${installer_path}/CodexMultiAgentLauncher.exe" \
        "${installer_path}/Launch-CodexMultiAgent.cmd" \
        "${installer_path}/Build-Launcher.ps1" \
        "${installer_path}/src"
}

get_source_kit_root() {
    if [ -f "${GLOBAL_KIT_ROOT}/GLOBAL_AGENTS_TEMPLATE.md" ]; then
        printf '%s\n' "$GLOBAL_KIT_ROOT"
    else
        printf '%s\n' "$LOCAL_KIT_ROOT"
    fi
}

get_workspace_template_source() {
    source_kit_root="$1"
    template_name="$2"

    case "$template_name" in
        standard) printf '%s\n' "${source_kit_root}/WORKSPACE_OVERRIDE_TEMPLATE.md" ;;
        minimal) printf '%s\n' "${source_kit_root}/WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md" ;;
        *) printf 'Unsupported template: %s\n' "$template_name" >&2; exit 1 ;;
    esac
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

get_derived_repository_facts() {
    context_path="$1"

    load_context_array repository_facts "$context_path" "repository" "facts"
    display_name=$(toml_get_scalar "$context_path" "workspace" "display_name")
    page_kind=$(toml_get_scalar "$context_path" "workspace" "page_kind")
    primary_entry=$(toml_get_scalar "$context_path" "workspace" "primary_entry")
    page_url=$(toml_get_scalar "$context_path" "workspace" "page_url")
    locale=$(toml_get_scalar "$context_path" "workspace" "locale")
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

    if [ "${#shared_assets_a[@]:-0}" -gt 0 ]; then
        compress_path_like_items ${shared_assets_a[@]+"${shared_assets_a[@]}"}
        return
    fi

    if [ "${#shared_assets_b[@]:-0}" -gt 0 ]; then
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
    if [ "${#do_not_touch_b[@]:-0}" -gt 0 ]; then
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
    if [ "${#approval_a[@]:-0}" -gt 0 ]; then
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
    if [ "${#worker_mapping_a[@]:-0}" -gt 0 ]; then
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
    if [ "${#reviewer_focus_a[@]:-0}" -gt 0 ]; then
        merge_context_items ${reviewer_focus_a[@]+"${reviewer_focus_a[@]}"}
        return
    fi

    load_context_array reviewer_focus_b "$context_path" "verification" "manual_checks"
    load_context_array reviewer_focus_c "$context_path" "editing_rules" "notes"
    merge_context_items ${reviewer_focus_b[@]+"${reviewer_focus_b[@]}"} ${reviewer_focus_c[@]+"${reviewer_focus_c[@]}"}
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

    title=$(toml_get_scalar "$context_path" "workspace" "name")
    summary=$(get_derived_workspace_summary "$context_path" "$workspace_name")
    task_board_path=$(toml_get_scalar "$context_path" "workspace" "task_board_path")
    multi_agent_log_path=$(toml_get_scalar "$context_path" "workspace" "multi_agent_log_path")

    [ -n "$title" ] || title="$workspace_name"
    [ -n "$task_board_path" ] || task_board_path="STATE.md"
    [ -n "$multi_agent_log_path" ] || multi_agent_log_path="MULTI_AGENT_LOG.md"

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

        combined_facts=(${repository_facts[@]+"${repository_facts[@]}"} "Task board path: \`$task_board_path\`" "Multi-agent log path: \`$multi_agent_log_path\`")
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
        printf '  `explorer 3`, `reviewer 2`, `worker up to 4 on Route C`\n'
        printf -- '- Keep `%s` updated with exact `route`, concrete `reason`, `writer_slot`, `contract_freeze`, and `write_sets` when Route C is active\n' "$task_board_path"
        printf -- '- If multiple roles are used, append real participation to `%s` before reporting that they ran\n' "$multi_agent_log_path"
        if [ "$template_name" = "minimal" ]; then
            printf -- '- Keep changes small\n'
            printf -- '- Let this repository narrow Route A/B/C behavior further only when it truly needs stricter local rules\n'
        else
            printf -- '- Add repository-specific worker ownership, hard triggers, and approval zones here as they become clear\n'
            printf -- '- Let this repository narrow Route A/B/C behavior further only when it truly needs stricter local rules\n'
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

    load_array_from_command shared_contracts get_derived_shared_contracts "$context_path"
    load_array_from_command reviewer_focus get_derived_reviewer_focus "$context_path"

    if [ "${#shared_contracts[@]:-0}" -eq 0 ]; then
        shared_contracts=("n/a")
    fi

    if [ "${#reviewer_focus[@]:-0}" -eq 0 ]; then
        reviewer_focus=("n/a")
    fi

    {
        printf '# STATE\n\n'
        printf '## Current Task\n\n'
        printf -- '- id: `initial-task`\n'
        printf -- '- summary: `Replace with the first concrete task for %s before execution`\n' "$title"
        printf -- '- owner: `main`\n'
        printf -- '- phase: `explore`\n'
        printf '\n## Route\n\n'
        printf -- '- name: `Route A`\n'
        printf -- '- reason: `placeholder - classify the first task before editing`\n'
        printf '\n## Next Tasks\n\n'
        printf -- '- `Replace with the first concrete next step`\n'
        printf '\n## Blocked Tasks\n\n'
        printf -- '- `없음`\n'
        printf '\n## Writer Slot\n\n'
        printf -- '- status: `free`\n'
        printf -- '- target_scope: `n/a`\n'
        printf -- '- write_sets:\n'
        printf '  - `n/a`\n'
        printf '\n## Contract Freeze\n\n'
        printf -- '- status: `open`\n'
        printf -- '- shared_contracts:\n'
        for item in ${shared_contracts[@]+"${shared_contracts[@]}"}; do
            printf '  - `%s`\n' "$item"
        done
        printf -- '- freeze_owner: `main`\n'
        printf '\n## Reviewer\n\n'
        printf -- '- target: `n/a`\n'
        printf -- '- focus:\n'
        for item in ${reviewer_focus[@]+"${reviewer_focus[@]}"}; do
            printf '  - `%s`\n' "$item"
        done
        printf '\n## Last Update\n\n'
        printf -- '- updated_by: `main`\n'
        printf -- '- updated_at: `[timestamp]`\n'
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
    source_agents_root="${source_kit_root}/codex_agents"

    if [ ! -d "$source_agents_root" ]; then
        return
    fi

    ensure_directory "$GLOBAL_CUSTOM_AGENTS_ROOT"

    find "$source_agents_root" -maxdepth 1 -type f | while IFS= read -r source_file; do
        target="${GLOBAL_CUSTOM_AGENTS_ROOT}/$(basename "$source_file")"

        if should_overwrite_file "$target"; then
            cp "$source_file" "$target"
        else
            printf 'Skipped subagent config overwrite: %s\n' "$target"
        fi
    done
}

install_codex_rules() {
    source_kit_root="$1"
    source_rules_root="${source_kit_root}/codex_rules"

    if [ ! -d "$source_rules_root" ]; then
        return
    fi

    ensure_directory "$GLOBAL_RULES_ROOT"

    find "$source_rules_root" -maxdepth 1 -type f | while IFS= read -r source_file; do
        target="${GLOBAL_RULES_ROOT}/$(basename "$source_file")"

        if should_overwrite_file "$target"; then
            cp "$source_file" "$target"
        else
            printf 'Skipped rules overwrite: %s\n' "$target"
        fi
    done
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

    for item in \
        README.md \
        AGENTS_TEMPLATE.md \
        GLOBAL_AGENTS_TEMPLATE.md \
        STATE_TEMPLATE.md \
        WORKSPACE_CONTEXT_TEMPLATE.toml \
        WORKSPACE_OVERRIDE_TEMPLATE.md \
        WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md \
        MULTI_AGENT_GUIDE.md \
        CHANGELOG.md \
        codex_agents \
        codex_rules \
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

    global_template="${LOCAL_KIT_ROOT}/GLOBAL_AGENTS_TEMPLATE.md"
    if ! should_overwrite_file "$GLOBAL_AGENTS_PATH"; then
        printf 'Skipped global AGENTS.md overwrite\n'
        return
    fi

    cp "$global_template" "$GLOBAL_AGENTS_PATH"
    install_codex_custom_agents "$LOCAL_KIT_ROOT"
    install_codex_rules "$LOCAL_KIT_ROOT"

    printf 'Installed global defaults at %s\n' "$GLOBAL_AGENTS_PATH"
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
    template_source=$(get_workspace_template_source "$source_kit_root" "$template_name")
    agents_target="${resolved_workspace}/AGENTS.md"
    state_template="${source_kit_root}/STATE_TEMPLATE.md"
    state_relative_path=$(toml_get_scalar "$context_path" "workspace" "task_board_path")
    [ -n "$state_relative_path" ] || state_relative_path="STATE.md"
    state_target="${resolved_workspace}/${state_relative_path}"

    write_section 'Applying workspace override'
    printf 'Workspace: %s\n' "$resolved_workspace"
    printf 'Template: %s\n' "$template_name"
    printf 'Supporting docs: %s\n' "$copy_docs"
    if [ -f "$context_path" ]; then
        printf 'Workspace context: %s\n' "$context_path"
    fi

    if ! should_overwrite_file "$agents_target"; then
        printf 'Skipped AGENTS.md overwrite\n'
        return
    fi

    if [ -f "$context_path" ]; then
        generate_workspace_agents_from_context "$context_path" "$(basename "$resolved_workspace")" "$template_name" "$agents_target"
    else
        cp "$template_source" "$agents_target"
    fi

    if [ ! -e "$state_target" ]; then
        ensure_directory "$(dirname "$state_target")"
        if [ -f "$context_path" ]; then
            generate_workspace_state_from_context "$context_path" "$(basename "$resolved_workspace")" "$state_target"
        else
            cp "$state_template" "$state_target"
        fi
    fi

    if [ "$copy_docs" -eq 1 ]; then
        docs_root="${resolved_workspace}/docs/codex-multiagent"

        ensure_directory "$docs_root"

        cp "${source_kit_root}/README.md" "${docs_root}/README.md"
        cp "${source_kit_root}/CHANGELOG.md" "${docs_root}/CHANGELOG.md"
        cp "${source_kit_root}/MULTI_AGENT_GUIDE.md" "${docs_root}/MULTI_AGENT_GUIDE.md"
        cp "${source_kit_root}/GLOBAL_AGENTS_TEMPLATE.md" "${docs_root}/GLOBAL_AGENTS_TEMPLATE.md"
        cp "${source_kit_root}/STATE_TEMPLATE.md" "${docs_root}/STATE_TEMPLATE.md"
        cp "${source_kit_root}/WORKSPACE_CONTEXT_TEMPLATE.toml" "${docs_root}/WORKSPACE_CONTEXT_TEMPLATE.toml"
        cp "${source_kit_root}/WORKSPACE_OVERRIDE_TEMPLATE.md" "${docs_root}/WORKSPACE_OVERRIDE_TEMPLATE.md"
        cp "${source_kit_root}/WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md" "${docs_root}/WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md"

        if [ -d "${source_kit_root}/codex_agents" ]; then
            copy_directory_contents "${source_kit_root}/codex_agents" "${docs_root}/codex_agents"
        fi

        if [ -d "${source_kit_root}/codex_rules" ]; then
            copy_directory_contents "${source_kit_root}/codex_rules" "${docs_root}/codex_rules"
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
