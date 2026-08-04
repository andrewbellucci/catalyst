#!/bin/sh
set -eu

swift build -c release

app_dir=".build/Catalyst.app"
contents_dir="$app_dir/Contents"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp ".build/release/Catalyst" "$contents_dir/MacOS/Catalyst"
cp "Resources/Info.plist" "$contents_dir/Info.plist"
cp "Resources/Catalyst.icns" "$contents_dir/Resources/Catalyst.icns"
cp "Resources/CatalystGlyph.svg" "$contents_dir/Resources/CatalystGlyph.svg"
codesign --force --sign - "$app_dir"

echo "$PWD/$app_dir"
