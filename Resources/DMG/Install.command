#!/bin/bash
# MacRAR install helper:
#  1. Strip Gatekeeper quarantine (ad-hoc signed; no Developer ID)
#  2. Re-register with Launch Services so file associations work
#  3. Enable our Services menu items so right-click → Services shows them
set -e
APP="/Applications/MacRAR.app"
BUNDLE_ID="com.bechou.winrar"

if [[ ! -d "$APP" ]]; then
  osascript -e 'display dialog "Please drag MacRAR.app to your Applications folder first, then run Install.command again." buttons {"OK"} default button "OK" with icon caution with title "MacRAR Install"'
  exit 1
fi

# 1. Allow Gatekeeper
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

# 2. Register with Launch Services (file associations, Services menu)
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f -R -trusted "$APP" >/dev/null 2>&1 || true

# 3. Refresh Services + enable our items
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
sleep 1
defaults write pbs NSServicesStatus -dict-add \
  "$BUNDLE_ID - Compress with MacRAR… - compressService" \
  '{"enabled_context_menu" = 1; "enabled_services_menu" = 1;}' >/dev/null 2>&1 || true
defaults write pbs NSServicesStatus -dict-add \
  "$BUNDLE_ID - Extract with MacRAR - extractService" \
  '{"enabled_context_menu" = 1; "enabled_services_menu" = 1;}' >/dev/null 2>&1 || true
killall pbs 2>/dev/null || true
killall Finder 2>/dev/null || true

osascript -e 'display dialog "MacRAR is ready.

Right-click any file or folder in Finder → Services to see:
  • Compress with MacRAR…
  • Extract with MacRAR" buttons {"OK"} default button "OK" with title "MacRAR Install"'
