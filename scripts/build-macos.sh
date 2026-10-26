#!/bin/bash
set -euo pipefail

package_root="$(cd "$(dirname "$0")/.." && pwd)"
target_arch="${1:-universal}"
output_dir="$package_root/dist/$target_arch"

case "$target_arch" in
  arm64|x86_64)
    swift build --package-path "$package_root" -c release --product device-info --arch "$target_arch" --jobs 4
    binary_dir="$(swift build --package-path "$package_root" -c release --arch "$target_arch" --show-bin-path)"
    mkdir -p "$output_dir"
    cp "$binary_dir/device-info" "$output_dir/device-info"
    ;;
  universal)
    "$0" arm64
    "$0" x86_64
    mkdir -p "$output_dir"
    lipo -create "$package_root/dist/arm64/device-info" "$package_root/dist/x86_64/device-info" -output "$output_dir/device-info"
    ;;
  *)
    echo "Usage: $0 [universal|arm64|x86_64]" >&2
    exit 64
    ;;
esac

# This local signature supports smoke tests. Electron releases must sign this helper
# with the application's Developer ID identity before signing/notarizing the app.
codesign --force --sign - "$output_dir/device-info"
echo "$output_dir/device-info"
