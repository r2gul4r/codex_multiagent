#!/usr/bin/env bash

set -eu

ZIP_URL="${CODEX_MULTIAGENT_ZIP_URL:-https://github.com/r2gul4r/codex_multiagent/archive/refs/heads/main.zip}"
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/codex-multiagent-XXXXXX")
ZIP_PATH="${TEMP_ROOT}/kit.zip"
EXTRACT_PATH="${TEMP_ROOT}/extract"

cleanup() {
    rm -rf "$TEMP_ROOT"
}

trap cleanup EXIT INT TERM

mkdir -p "$EXTRACT_PATH"

if ! command -v curl >/dev/null 2>&1; then
    printf 'curl is required\n' >&2
    exit 1
fi

curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"

if command -v unzip >/dev/null 2>&1; then
    unzip -q "$ZIP_PATH" -d "$EXTRACT_PATH"
elif command -v ditto >/dev/null 2>&1; then
    ditto -x -k "$ZIP_PATH" "$EXTRACT_PATH"
elif command -v python3 >/dev/null 2>&1; then
    python3 -m zipfile -e "$ZIP_PATH" "$EXTRACT_PATH"
else
    printf 'One of unzip, ditto, or python3 is required to extract the archive\n' >&2
    exit 1
fi

KIT_ROOT=$(find "$EXTRACT_PATH" -mindepth 1 -maxdepth 1 -type d | head -n 1)
INSTALLER_PATH="${KIT_ROOT}/installer/CodexMultiAgent.sh"

if [ -z "${KIT_ROOT:-}" ] || [ ! -f "$INSTALLER_PATH" ]; then
    printf 'Failed to locate CodexMultiAgent.sh in downloaded archive\n' >&2
    exit 1
fi

bash "$INSTALLER_PATH" "$@" --force --no-prompt
