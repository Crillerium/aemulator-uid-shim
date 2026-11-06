#!/usr/bin/env bash
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SU_FILE="$REPO_ROOT/src/su"
JAR_FILE="$REPO_ROOT/dist/aemu-su.jar"

FORCE=0
if [ "${1:-}" = "--force" ]; then
    FORCE=1
    shift
fi
SERIAL="${1:-}"

ADB_BIN="${ADB:-}"
if [ -z "$ADB_BIN" ]; then
    ADB_BIN="$(command -v adb || true)"
fi
if [ -z "$ADB_BIN" ] && [ -x "$HOME/Android/Sdk/platform-tools/adb" ]; then
    ADB_BIN="$HOME/Android/Sdk/platform-tools/adb"
fi
if [ -z "$ADB_BIN" ] && [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
    ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
fi
if [ -z "$ADB_BIN" ]; then
    echo "ERROR: adb not found. Set ADB or add adb to PATH." >&2
    exit 1
fi

if [ ! -f "$JAR_FILE" ]; then
    echo "dist/aemu-su.jar not found; building it now."
    "$REPO_ROOT/scripts/build.sh"
fi
if [ ! -f "$SU_FILE" ] || [ ! -f "$JAR_FILE" ]; then
    echo "ERROR: source or JAR file is missing." >&2
    exit 1
fi

if [ -z "$SERIAL" ]; then
    devices="$("$ADB_BIN" devices | awk '$2 == "device" { print $1 }')"
    count="$(printf '%s\n' "$devices" | awk 'NF { n++ } END { print n + 0 }')"
    if [ "$count" -ne 1 ]; then
        echo "ERROR: expected exactly one online ADB device, found $count." >&2
        echo "Usage: $0 [--force] [serial]" >&2
        exit 1
    fi
    SERIAL="$devices"
fi

device_state="$("$ADB_BIN" -s "$SERIAL" get-state 2>/dev/null || true)"
if [ "$device_state" != "device" ]; then
    echo "ERROR: ADB device $SERIAL is not ready: ${device_state:-unknown}" >&2
    exit 1
fi

state="$("$ADB_BIN" -s "$SERIAL" shell \
    "if [ -f /system/bin/su ]; then if grep -q 'aemu.su.Main' /system/bin/su; then echo ours; else echo other; fi; else echo absent; fi" \
    | tr -d '\r')"
if [ "$state" = "other" ] && [ "$FORCE" -ne 1 ]; then
    echo "ERROR: /system/bin/su exists and is not managed by this project." >&2
    echo "Back it up first, then re-run with --force." >&2
    exit 1
fi

"$ADB_BIN" -s "$SERIAL" push "$SU_FILE" /system/bin/su
"$ADB_BIN" -s "$SERIAL" push "$JAR_FILE" /system/framework/aemu-su.jar
"$ADB_BIN" -s "$SERIAL" shell chmod 755 /system/bin/su

version="$("$ADB_BIN" -s "$SERIAL" shell su -v | tr -d '\r')"
identity="$("$ADB_BIN" -s "$SERIAL" shell su -c id | tr -d '\r')"
case "$identity" in
    *"uid=0(root)"*) ;;
    *)
        echo "ERROR: su -c id did not return UID 0: $identity" >&2
        exit 1
        ;;
esac

echo "Installed AEmulator UID Shim on $SERIAL"
echo "  su -v:    $version"
echo "  su -c id: $identity"
echo "This is an emulated identity, not Magisk or a real kernel root."
