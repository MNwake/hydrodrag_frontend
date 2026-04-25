#!/usr/bin/env bash
# Build Android release artifacts for Google Play (AAB) and/or device debugging (APK).
# Uses production API URL so the build matches what goes to the store.
# Usage: ./build_appbundle_playstore.sh          # AAB only
#        ./build_appbundle_playstore.sh --apk     # AAB + APK (APK for install on device)
set -e
cd "$(dirname "$0")"

export API_BASE_URL='https://api.hydrodrags.koesterventures.com'
BUILD_APK=false
for arg in "$@"; do
  [ "$arg" = "--apk" ] && BUILD_APK=true
done

echo "Building release AAB with API_BASE_URL=$API_BASE_URL"
flutter build appbundle --dart-define=API_BASE_URL="$API_BASE_URL"

if [ "$BUILD_APK" = true ]; then
  echo ""
  echo "Building release APK (same config as AAB) for device install..."
  flutter build apk --dart-define=API_BASE_URL="$API_BASE_URL"
  echo ""
  echo "APK for device install:"
  echo "  build/app/outputs/flutter-apk/app-release.apk"
  echo ""
fi

echo "Done. Upload this file to Play Console:"
echo "  build/app/outputs/bundle/release/app-release.aab"
echo ""
