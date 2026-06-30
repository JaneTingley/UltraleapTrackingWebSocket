#!/usr/bin/env sh

set -e

BINARY="$1"
LIB_SOURCE="$2"
BUILD_DIR=$(dirname "$BINARY")

# 1. Resolve symlink (just in case)
RESOLVED_LIB=$(readlink -f "$LIB_SOURCE")
LIB_NAME=$(basename "$RESOLVED_LIB")

echo "📦 Bundling: $LIB_NAME"

# 2. Copy the library
cp "$RESOLVED_LIB" "$BUILD_DIR/$LIB_NAME"
echo "   Copied to: $BUILD_DIR/$LIB_NAME"

# 3. Fix internal ID
install_name_tool -id "@loader_path/$LIB_NAME" "$BUILD_DIR/$LIB_NAME"
echo "   Set internal ID: @loader_path/$LIB_NAME"

# 4. Fix binary reference
OLD_PATH=$(otool -L "$BINARY" | grep "$LIB_NAME" | head -1 | awk '{print $1}')

if [ -n "$OLD_PATH" ]; then
    echo "   Found reference: $OLD_PATH"
    install_name_tool -change "$OLD_PATH" "@loader_path/$LIB_NAME" "$BINARY"
    echo "   ✅ Success!"
else
    echo "   ⚠️  No reference found (might already be local)."
fi

echo "   ✅ Bundling complete."