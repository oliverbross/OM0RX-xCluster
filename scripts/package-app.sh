#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/OM0RX-xCluster.app"
contents_dir="$app_dir/Contents"

swift build --package-path "$repo_dir" -c release
bin_dir="$(swift build --package-path "$repo_dir" -c release --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$bin_dir/om0rx-xcluster" "$contents_dir/MacOS/om0rx-xcluster"
cp "$repo_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$repo_dir/Resources/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"
for bundle in "$bin_dir"/*.bundle; do
    [[ -e "$bundle" ]] && cp -R "$bundle" "$contents_dir/Resources/"
done
chmod 755 "$contents_dir/MacOS/om0rx-xcluster"

signing_identity="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
    identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    signing_identity="$(print -r -- "$identity_output" | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | sed -n '1p')"
fi
signing_identity="${signing_identity:--}"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --deep --sign - "$app_dir"
else
    codesign --force --deep --options runtime --timestamp --entitlements "$repo_dir/Resources/OM0RXXCluster.entitlements" --sign "$signing_identity" "$app_dir"
fi
codesign --verify --deep --strict --verbose=2 "$app_dir"
print "$app_dir"
