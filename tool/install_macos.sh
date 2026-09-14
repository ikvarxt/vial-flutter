#!/usr/bin/env bash
# Builds the release app and installs it into /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter --suppress-analytics build macos --release
APP=build/macos/Build/Products/Release/vial_flutter.app
rm -rf /Applications/vial_flutter.app
ditto "$APP" /Applications/vial_flutter.app
echo "installed /Applications/vial_flutter.app"
