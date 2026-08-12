#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/MacRight.app/Contents"
EXT_DIR="$APP_DIR/PlugIns/FinderSyncExtension.appex/Contents"
VERSION="${1#v}"
if [ -z "$VERSION" ]; then
  VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/MacRight/Info.plist")
fi

echo "==> Cleaning..."
rm -rf "$BUILD_DIR"

echo "==> Creating bundle structure..."
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
mkdir -p "$EXT_DIR/MacOS" "$EXT_DIR/Resources/Templates"

HOST_SOURCES=(
  "$PROJECT_DIR/Shared/Constants.swift"
  "$PROJECT_DIR/Shared/Preferences.swift"
  "$PROJECT_DIR/MacRight/MacRightApp.swift"
  "$PROJECT_DIR/MacRight/Views/ContentView.swift"
  "$PROJECT_DIR/MacRight/Views/SettingsView.swift"
)

EXT_SOURCES=(
  "$PROJECT_DIR/Shared/Constants.swift"
  "$PROJECT_DIR/Shared/Preferences.swift"
  "$PROJECT_DIR/FinderSyncExtension/FinderSync.swift"
  "$PROJECT_DIR/FinderSyncExtension/Actions/FileCreator.swift"
  "$PROJECT_DIR/FinderSyncExtension/Actions/TerminalLauncher.swift"
  "$PROJECT_DIR/FinderSyncExtension/Actions/CmuxLauncher.swift"
)

echo "==> Compiling host app (universal binary)..."
for ARCH in arm64 x86_64; do
  swiftc \
    -sdk "$SDK_PATH" \
    -target ${ARCH}-apple-macosx13.0 \
    -F "$SDK_PATH/System/Library/Frameworks" \
    -framework Cocoa -framework FinderSync -framework SwiftUI \
    -module-name MacRight \
    -emit-executable \
    -o "$BUILD_DIR/MacRight_${ARCH}" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    "${HOST_SOURCES[@]}"
done
lipo -create "$BUILD_DIR/MacRight_arm64" "$BUILD_DIR/MacRight_x86_64" -output "$APP_DIR/MacOS/MacRight"
rm "$BUILD_DIR/MacRight_arm64" "$BUILD_DIR/MacRight_x86_64"

echo "==> Compiling Finder Sync Extension (universal binary)..."
for ARCH in arm64 x86_64; do
  swiftc \
    -sdk "$SDK_PATH" \
    -target ${ARCH}-apple-macosx13.0 \
    -F "$SDK_PATH/System/Library/Frameworks" \
    -framework FinderSync -framework Cocoa -framework UniformTypeIdentifiers \
    -module-name FinderSyncExtension \
    -emit-executable \
    -o "$BUILD_DIR/FinderSyncExtension_${ARCH}" \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -Xlinker -rpath -Xlinker @executable_path/../../../../Frameworks \
    -Xlinker -e -Xlinker _NSExtensionMain \
    "${EXT_SOURCES[@]}"
done
lipo -create "$BUILD_DIR/FinderSyncExtension_arm64" "$BUILD_DIR/FinderSyncExtension_x86_64" -output "$EXT_DIR/MacOS/FinderSyncExtension"
rm "$BUILD_DIR/FinderSyncExtension_arm64" "$BUILD_DIR/FinderSyncExtension_x86_64"

echo "==> Copying resources..."
cp "$PROJECT_DIR/FinderSyncExtension/Resources/Templates/blank."* "$EXT_DIR/Resources/Templates/"

# Host app Info.plist
cp "$PROJECT_DIR/MacRight/Info.plist" "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string MacRight' "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.macright.app' "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleInfoDictionaryVersion string 6.0' "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSPrincipalClass string NSApplication' "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$APP_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Info.plist"

# Extension Info.plist
cp "$PROJECT_DIR/FinderSyncExtension/Info.plist" "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string FinderSyncExtension' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.macright.app.FinderSyncExtension' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string XPC!' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleInfoDictionaryVersion string 6.0' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDevelopmentRegion string en' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSPrincipalClass string NSApplication' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleSupportedPlatforms array' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleSupportedPlatforms:0 string MacOSX' "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$EXT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :NSExtension:NSExtensionPrincipalClass FinderSyncExtension.FinderSync' "$EXT_DIR/Info.plist"

echo -n "APPL????" > "$APP_DIR/PkgInfo"

echo "==> Signing..."
codesign --force --sign - --entitlements "$PROJECT_DIR/FinderSyncExtension/FinderSyncExtension.entitlements" "$BUILD_DIR/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex"
codesign --force --sign - --entitlements "$PROJECT_DIR/MacRight/MacRight.entitlements" "$BUILD_DIR/MacRight.app"

# CI 模式：仅构建签名，不安装到本地
if [ "${CI:-}" = "true" ]; then
  echo "==> Done! (CI mode, skip local install)"
  exit 0
fi

echo "==> Installing to /Applications..."
killall MacRight 2>/dev/null || true
rm -rf /Applications/MacRight.app
cp -R "$BUILD_DIR/MacRight.app" /Applications/MacRight.app
codesign --force --sign - --entitlements "$PROJECT_DIR/FinderSyncExtension/FinderSyncExtension.entitlements" /Applications/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex
codesign --force --sign - --entitlements "$PROJECT_DIR/MacRight/MacRight.entitlements" /Applications/MacRight.app

echo "==> Cleaning build dir extension to avoid duplicate registration..."
rm -rf "$BUILD_DIR/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$BUILD_DIR/MacRight.app" 2>/dev/null || true

echo "==> Registering extension..."
killall pkd 2>/dev/null || true
sleep 1
pluginkit -e use -i com.macright.app.FinderSyncExtension 2>/dev/null || true

echo "==> Done! Launching..."
open /Applications/MacRight.app
sleep 2
pluginkit -m -p com.apple.FinderSync 2>/dev/null
