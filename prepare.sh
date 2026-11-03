#!/usr/bin/env bash
# Makes the Android + iOS project folders for one app (they are generated, not stored in git) and sets its name, id and icon.
# Usage (from the app folder):  bash ../prepare.sh com.peachpiper.shop "Peach Piper"
set -euo pipefail
BUNDLE_ID="$1"; APP_NAME="$2"
PROJECT=$(grep '^name:' pubspec.yaml | awk '{print $2}')

flutter create --org com.peachpiper --project-name "$PROJECT" --platforms=android,ios . >/dev/null
flutter pub get

# ---- Android: internet permission, app name, application id (perl works the same on macOS and Linux) ----
MAN=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' "$MAN" || perl -0pi -e 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MAN"
APP_NAME="$APP_NAME" perl -pi -e 's#android:label="[^"]*"#android:label="$ENV{APP_NAME}"#' "$MAN"
# tel:, mailto:, https and WhatsApp links (Android 11+ needs these declared)
grep -q 'android.intent.action.DIAL' "$MAN" || perl -0pi -e 's#</manifest>#    <queries>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>\n        <package android:name="com.whatsapp"/>\n        <package android:name="com.whatsapp.w4b"/>\n    </queries>\n</manifest>#' "$MAN"
for G in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$G" ] || continue
  BUNDLE_ID="$BUNDLE_ID" perl -pi -e 's#applicationId\s*=?\s*"[^"]+"#applicationId = "$ENV{BUNDLE_ID}"#; s#namespace\s*=?\s*"[^"]+"#namespace = "$ENV{BUNDLE_ID}"#; s#minSdk\s*=\s*flutter\.minSdkVersion#minSdk = 21#' "$G"
done
# MainActivity must sit in the package that matches the namespace
OLD_MAIN=$(find android/app/src/main -name 'MainActivity.kt' | head -1)
if [ -n "$OLD_MAIN" ]; then
  NEW_DIR="android/app/src/main/kotlin/$(echo "$BUNDLE_ID" | tr '.' '/')"
  mkdir -p "$NEW_DIR"
  sed -E "s#^package .*#package $BUNDLE_ID#" "$OLD_MAIN" > "$NEW_DIR/MainActivity.kt.new"
  [ "$OLD_MAIN" != "$NEW_DIR/MainActivity.kt" ] && rm -f "$OLD_MAIN"
  mv "$NEW_DIR/MainActivity.kt.new" "$NEW_DIR/MainActivity.kt"
fi

# ---- iOS: bundle id, display name, minimum iOS 13, WhatsApp / phone links ----
PBX=ios/Runner.xcodeproj/project.pbxproj
BUNDLE_ID="$BUNDLE_ID" perl -pi -e 's#PRODUCT_BUNDLE_IDENTIFIER = [^;]*RunnerTests;#PRODUCT_BUNDLE_IDENTIFIER = $ENV{BUNDLE_ID}.RunnerTests;#g; s#PRODUCT_BUNDLE_IDENTIFIER = com\.peachpiper\.[A-Za-z0-9_]+;#PRODUCT_BUNDLE_IDENTIFIER = $ENV{BUNDLE_ID};#g; s#IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;#IPHONEOS_DEPLOYMENT_TARGET = 13.0;#g' "$PBX"
PL=ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$PL" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$PL" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :LSApplicationQueriesSchemes" "$PL" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :LSApplicationQueriesSchemes array" -c "Add :LSApplicationQueriesSchemes:0 string whatsapp" -c "Add :LSApplicationQueriesSchemes:1 string tel" -c "Add :LSApplicationQueriesSchemes:2 string mailto" -c "Add :LSApplicationQueriesSchemes:3 string upi" -c "Add :LSApplicationQueriesSchemes:4 string tez" -c "Add :LSApplicationQueriesSchemes:5 string phonepe" -c "Add :LSApplicationQueriesSchemes:6 string paytmmp" "$PL" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PL" 2>/dev/null || true
[ -f ios/Podfile ] && perl -pi -e "s/^# platform :ios, .*/platform :ios, '13.0'/" ios/Podfile || true

# ---- icons ----
dart run flutter_launcher_icons
echo "Prepared $APP_NAME ($BUNDLE_ID)"
