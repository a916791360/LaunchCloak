#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APP_NAME="LaunchCloak"
BUNDLE_DIR="$DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 🚀 开始编译 $APP_NAME (Swift 6.x / macOS 26+)..."

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 1. 复制 App 图标
if [ -f "$DIR/AppIcon.icns" ]; then
    cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# 2. 编译 Universal 2 双架构二进制 (Apple Silicon arm64 + Intel x86_64)
echo "==> ⚙️ 编译 Apple Silicon (arm64)..."
swiftc -parse-as-library \
  -O \
  -target arm64-apple-macosx14.0 \
  "$DIR/src/Models.swift" \
  "$DIR/src/SettingsManager.swift" \
  "$DIR/src/SettingsWindowController.swift" \
  "$DIR/src/SettingsView.swift" \
  "$DIR/src/UpdateChecker.swift" \
  "$DIR/src/AppManager.swift" \
  "$DIR/src/Views.swift" \
  "$DIR/src/main.swift" \
  -o "/tmp/${APP_NAME}_arm64"

echo "==> ⚙️ 编译 Intel (x86_64)..."
swiftc -parse-as-library \
  -O \
  -target x86_64-apple-macosx14.0 \
  "$DIR/src/Models.swift" \
  "$DIR/src/SettingsManager.swift" \
  "$DIR/src/SettingsWindowController.swift" \
  "$DIR/src/SettingsView.swift" \
  "$DIR/src/UpdateChecker.swift" \
  "$DIR/src/AppManager.swift" \
  "$DIR/src/Views.swift" \
  "$DIR/src/main.swift" \
  -o "/tmp/${APP_NAME}_x86_64"

echo "==> 🔀 合并生成 Universal 2 通用二进制文件..."
lipo -create "/tmp/${APP_NAME}_arm64" "/tmp/${APP_NAME}_x86_64" -output "$MACOS_DIR/$APP_NAME"
rm -f "/tmp/${APP_NAME}_arm64" "/tmp/${APP_NAME}_x86_64"

# 3. 生成 Info.plist
cat << EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.qingmeng.launchcloak</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>LaunchCloak</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.3</string>
    <key>CFBundleVersion</key>
    <string>10</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 4. Ad-hoc 本地代码签名
codesign --force --deep --sign - "$BUNDLE_DIR" >/dev/null 2>&1 || true

echo "==> ✅ 打包完成！生成应用位于: $BUNDLE_DIR"

if [ "$1" == "--run" ]; then
    echo "==> 启动应用..."
    open "$BUNDLE_DIR"
fi
