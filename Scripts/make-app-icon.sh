#!/bin/bash
# Generate AppIcon.appiconset from a single 1024×1024 master PNG.
#
# Pipeline:
#   1. Run `generate-app-icon.swift` to draw the master PNG
#   2. `sips -z` to downsample for every iconset slot
#   3. Write Contents.json mapping slots → filenames
#
# Output lands directly in Sources/MacRAR/Assets.xcassets/AppIcon.appiconset/
set -euo pipefail

SRC="${SRCROOT:-$(pwd)}"
MASTER="/tmp/macrar-icon-1024.png"
ICONSET="${SRC}/Sources/MacRAR/Assets.xcassets/AppIcon.appiconset"

echo "→ Drawing master 1024×1024 PNG"
swift "${SRC}/Scripts/generate-app-icon.swift" "${MASTER}"

rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"

# slot:size pairs for macOS AppIcon
declare -a SLOTS=(
  "icon_16x16.png:16"
  "icon_16x16@2x.png:32"
  "icon_32x32.png:32"
  "icon_32x32@2x.png:64"
  "icon_128x128.png:128"
  "icon_128x128@2x.png:256"
  "icon_256x256.png:256"
  "icon_256x256@2x.png:512"
  "icon_512x512.png:512"
  "icon_512x512@2x.png:1024"
)

echo "→ Resampling to all sizes"
for slot in "${SLOTS[@]}"; do
  name="${slot%%:*}"
  size="${slot##*:}"
  sips -z "${size}" "${size}" "${MASTER}" --out "${ICONSET}/${name}" >/dev/null
done

echo "→ Writing Contents.json"
cat > "${ICONSET}/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon_16x16.png",     "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png",     "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png",   "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png","idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",   "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png","idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",   "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png","idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "macrar", "version" : 1 }
}
EOF

# Asset catalog top-level Contents.json (if not exists)
CATALOG_ROOT="${SRC}/Sources/MacRAR/Assets.xcassets"
if [[ ! -f "${CATALOG_ROOT}/Contents.json" ]]; then
  cat > "${CATALOG_ROOT}/Contents.json" <<'EOF'
{ "info" : { "author" : "macrar", "version" : 1 } }
EOF
fi

rm -f "${MASTER}"
echo "✓ AppIcon written to ${ICONSET}"
