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

# 1. 编译二进制文件
swiftc -parse-as-library \
  -O \
  "$DIR/src/Models.swift" \
  "$DIR/src/AppManager.swift" \
  "$DIR/src/Views.swift" \
  "$DIR/src/main.swift" \
  -o "$MACOS_DIR/$APP_NAME"

# 2. 生成 Info.plist
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
    <string>LaunchCloak (隐符)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 3. Ad-hoc 本地代码签名
codesign --force --deep --sign - "$BUNDLE_DIR" >/dev/null 2>&1 || true

echo "==> ✅ 打包完成！生成应用位于: $BUNDLE_DIR"

if [ "$1" == "--run" ]; then
    echo "==> 启动应用..."
    open "$BUNDLE_DIR"
fi
