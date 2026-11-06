#!/usr/bin/env bash
set -eu

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

if [ -z "$SERIAL" ]; then
    devices="$("$ADB_BIN" devices | awk '$2 == "device" { print $1 }')"
    count="$(printf '%s\n' "$devices" | awk 'NF { n++ } END { print n + 0 }')"
    if [ "$count" -ne 1 ]; then
        echo "ERROR: expected exactly one online ADB device, found $count." >&2
        echo "Usage: $0 [serial]" >&2
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

if [ "$state" = "ours" ]; then
    "$ADB_BIN" -s "$SERIAL" shell rm -f /system/bin/su
elif [ "$state" = "other" ]; then
    echo "WARNING: leaving /system/bin/su in place because it is not managed by this project." >&2
fi

"$ADB_BIN" -s "$SERIAL" shell rm -f /system/framework/aemu-su.jar
echo "Uninstalled AEmulator UID Shim from $SERIAL"
