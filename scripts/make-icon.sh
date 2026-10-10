#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
source_png="$repo_dir/Resources/AppIcon.png"
iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source_png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$source_png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$iconset" -o "$repo_dir/Resources/AppIcon.icns"
print "$repo_dir/Resources/AppIcon.icns"
