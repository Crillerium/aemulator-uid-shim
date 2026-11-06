#!/usr/bin/env bash
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$REPO_ROOT/src/aemu/su/Main.java"
BUILD_DIR="$REPO_ROOT/build"
DIST_DIR="$REPO_ROOT/dist"

if ! command -v javac >/dev/null 2>&1 || ! command -v jar >/dev/null 2>&1; then
    echo "ERROR: javac and jar must be available in PATH." >&2
    exit 1
fi

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [ -z "$SDK" ]; then
    for candidate in \
        "$HOME/Android/Sdk" \
        "$HOME/Library/Android/sdk" \
        "$HOME/AppData/Local/Android/Sdk"
    do
        if [ -d "$candidate/platforms" ] && [ -d "$candidate/build-tools" ]; then
            SDK="$candidate"
            break
        fi
    done
fi

if [ -z "$SDK" ] || [ ! -d "$SDK/platforms" ] || [ ! -d "$SDK/build-tools" ]; then
    echo "ERROR: Android SDK not found. Set ANDROID_SDK_ROOT or ANDROID_HOME." >&2
    exit 1
fi

best_api=-1
ANDROID_JAR=""
for platform in "$SDK"/platforms/android-*; do
    [ -d "$platform" ] || continue
    api="${platform##*/android-}"
    case "$api" in
        ''|*[!0-9]*) continue ;;
    esac
    if [ "$api" -gt "$best_api" ] && [ -f "$platform/android.jar" ]; then
        best_api="$api"
        ANDROID_JAR="$platform/android.jar"
    fi
done

if [ -z "$ANDROID_JAR" ]; then
    echo "ERROR: No android.jar found under $SDK/platforms." >&2
    exit 1
fi

D8=""
for tool_dir in "$SDK"/build-tools/*; do
    [ -d "$tool_dir" ] || continue
    if [ -x "$tool_dir/d8" ]; then
        D8="$tool_dir/d8"
    fi
done

if [ -z "$D8" ]; then
    echo "ERROR: d8 not found under $SDK/build-tools." >&2
    exit 1
fi

if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR/classes" "$BUILD_DIR/dex" "$DIST_DIR"

javac -encoding UTF-8 -source 8 -target 8 \
    -classpath "$ANDROID_JAR" \
    -d "$BUILD_DIR/classes" \
    "$SOURCE_FILE"

"$D8" --min-api 21 --lib "$ANDROID_JAR" \
    --output "$BUILD_DIR/dex" \
    "$BUILD_DIR/classes/aemu/su/Main.class"

jar --create --file "$DIST_DIR/aemu-su.jar" \
    -C "$BUILD_DIR/dex" classes.dex

echo "Built $DIST_DIR/aemu-su.jar"
echo "Android SDK: $SDK"
