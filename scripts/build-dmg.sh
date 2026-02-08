#!/usr/bin/env bash
# =============================================================================
# build-dmg.sh — Build XRoads.app and package as DMG for distribution
# =============================================================================
#
# Usage:
#   ./scripts/build-dmg.sh              # Release build + DMG
#   ./scripts/build-dmg.sh --debug      # Debug build + DMG
#
# Output:
#   dist/XRoads-<version>.dmg
#   dist/XRoads.app
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_CONFIG="release"

# Parse args
if [[ "${1:-}" == "--debug" ]]; then
    BUILD_CONFIG="debug"
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
APP_NAME="XRoads"
BUNDLE_ID="io.neurogrid.xroads"
VERSION=$(grep -o '"[0-9]*\.[0-9]*\.[0-9]*"' "$PROJECT_ROOT/build/XRoads.app/Contents/Info.plist" 2>/dev/null | head -1 | tr -d '"' || echo "1.0.0")
BUILD_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "============================================"
echo "  XRoads DMG Builder"
echo "  Version: $VERSION | Config: $BUILD_CONFIG"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Build
# ---------------------------------------------------------------------------
echo "[1/5] Building ($BUILD_CONFIG)..."
cd "$PROJECT_ROOT"

if [[ "$BUILD_CONFIG" == "release" ]]; then
    swift build -c release 2>&1 | tail -3
    BINARY="$PROJECT_ROOT/.build/release/XRoads"
else
    swift build 2>&1 | tail -3
    BINARY="$PROJECT_ROOT/.build/debug/XRoads"
fi

if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi
echo "  Binary: $BINARY ($(du -h "$BINARY" | cut -f1))"

# ---------------------------------------------------------------------------
# Step 2: Create .app bundle
# ---------------------------------------------------------------------------
echo "[2/5] Creating app bundle..."

# Clean previous build
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BINARY" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
if [[ -f "$PROJECT_ROOT/build/XRoads.app/Contents/Info.plist" ]]; then
    cp "$PROJECT_ROOT/build/XRoads.app/Contents/Info.plist" "$CONTENTS/Info.plist"
else
    # Generate Info.plist
    cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Neurogrid. Apache License 2.0.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
fi

# Copy entitlements
if [[ -f "$PROJECT_ROOT/XRoads/XRoads.entitlements" ]]; then
    cp "$PROJECT_ROOT/XRoads/XRoads.entitlements" "$CONTENTS/entitlements.plist"
fi

# Copy Skills resources
if [[ -d "$PROJECT_ROOT/XRoads/Resources/Skills" ]]; then
    cp -R "$PROJECT_ROOT/XRoads/Resources/Skills" "$RESOURCES_DIR/Skills"
    echo "  Copied $(ls "$RESOURCES_DIR/Skills" | wc -l | tr -d ' ') skill files"
fi

# Copy SPM-bundled resources if they exist
SPM_RESOURCES="$PROJECT_ROOT/.build/$BUILD_CONFIG/XRoadsLib_XRoadsLib.bundle"
if [[ -d "$SPM_RESOURCES" ]]; then
    cp -R "$SPM_RESOURCES" "$RESOURCES_DIR/"
    echo "  Copied SPM resource bundle"
fi

# Copy MCP server (build if needed)
MCP_SRC="$PROJECT_ROOT/xroads-mcp"
MCP_DIST="$MCP_SRC/dist/index.js"
if [[ -d "$MCP_SRC" ]]; then
    if [[ ! -f "$MCP_DIST" ]]; then
        echo "  Building MCP server..."
        (cd "$MCP_SRC" && npm install --silent && npm run build --silent)
    fi
    if [[ -f "$MCP_DIST" ]]; then
        mkdir -p "$RESOURCES_DIR/xroads-mcp/dist"
        cp "$MCP_DIST" "$RESOURCES_DIR/xroads-mcp/dist/index.js"
        # Copy package.json for Node to resolve dependencies
        cp "$MCP_SRC/package.json" "$RESOURCES_DIR/xroads-mcp/"
        if [[ -d "$MCP_SRC/node_modules" ]]; then
            cp -R "$MCP_SRC/node_modules" "$RESOURCES_DIR/xroads-mcp/"
        fi
        echo "  Copied MCP server to bundle"
    else
        echo "  WARNING: MCP server build failed, dist/index.js not found"
    fi
fi

echo "  Bundle: $APP_BUNDLE"

# ---------------------------------------------------------------------------
# Step 3: Ad-hoc code sign
# ---------------------------------------------------------------------------
echo "[3/5] Code signing (ad-hoc)..."

# Ad-hoc sign — works for direct distribution without Apple Developer account
# Recipients may need to right-click > Open on first launch
codesign --force --deep --sign - \
    --entitlements "$PROJECT_ROOT/XRoads/XRoads.entitlements" \
    "$APP_BUNDLE" 2>&1

echo "  Signed with ad-hoc identity"

# Verify
codesign --verify --deep "$APP_BUNDLE" 2>&1 && echo "  Signature valid" || echo "  WARNING: Signature verification failed"

# ---------------------------------------------------------------------------
# Step 4: Create DMG
# ---------------------------------------------------------------------------
echo "[4/5] Creating DMG..."

# Remove old DMG
rm -f "$DMG_PATH"

# Create temporary DMG directory
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Create Applications symlink (for drag-to-install)
ln -s /Applications "$DMG_STAGING/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" 2>&1 | grep -v "^$"

# Cleanup staging
rm -rf "$DMG_STAGING"

echo "  DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"

# ---------------------------------------------------------------------------
# Step 5: Summary
# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Done!"
echo ""
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "  To install: Open DMG → Drag XRoads to Applications"
echo ""
echo "  NOTE: First launch requires right-click → Open"
echo "  (ad-hoc signed, not notarized by Apple)"
echo "============================================"
