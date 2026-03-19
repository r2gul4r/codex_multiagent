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
    template_source=$(get_workspace_template_source "$source_kit_root" "$template_name")
    agents_target="${resolved_workspace}/AGENTS.md"
    state_template="${source_kit_root}/STATE_TEMPLATE.md"
    state_target="${resolved_workspace}/STATE.md"

    write_section 'Applying workspace override'
    printf 'Workspace: %s\n' "$resolved_workspace"
    printf 'Template: %s\n' "$template_name"
    printf 'Supporting docs: %s\n' "$copy_docs"

    if ! should_overwrite_file "$agents_target"; then
        printf 'Skipped AGENTS.md overwrite\n'
        return
    fi

    cp "$template_source" "$agents_target"

    if [ ! -e "$state_target" ]; then
        cp "$state_template" "$state_target"
    fi

    if [ "$copy_docs" -eq 1 ]; then
        docs_root="${resolved_workspace}/docs/codex-multiagent"

        ensure_directory "$docs_root"

        cp "${source_kit_root}/README.md" "${docs_root}/README.md"
        cp "${source_kit_root}/CHANGELOG.md" "${docs_root}/CHANGELOG.md"
        cp "${source_kit_root}/MULTI_AGENT_GUIDE.md" "${docs_root}/MULTI_AGENT_GUIDE.md"
        cp "${source_kit_root}/GLOBAL_AGENTS_TEMPLATE.md" "${docs_root}/GLOBAL_AGENTS_TEMPLATE.md"
        cp "${source_kit_root}/STATE_TEMPLATE.md" "${docs_root}/STATE_TEMPLATE.md"
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
