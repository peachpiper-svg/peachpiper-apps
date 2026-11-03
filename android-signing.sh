#!/usr/bin/env bash
# Signs the release build with the upload keystore Codemagic provides (CM_KEYSTORE_* env vars). Run from the app folder after prepare.sh.
set -euo pipefail
[ -n "${CM_KEYSTORE_PATH:-}" ] || { echo "No keystore set in Codemagic (android_signing)"; exit 1; }
G=android/app/build.gradle.kts
if [ -f "$G" ]; then
  grep -q 'create("release")' "$G" || perl -0pi -e 's#(\n\s*buildTypes\s*\{)#\n    signingConfigs {\n        create("release") {\n            storeFile = file(System.getenv("CM_KEYSTORE_PATH"))\n            storePassword = System.getenv("CM_KEYSTORE_PASSWORD")\n            keyAlias = System.getenv("CM_KEY_ALIAS")\n            keyPassword = System.getenv("CM_KEY_PASSWORD")\n        }\n    }\n$1#' "$G"
  perl -pi -e 's#signingConfig = signingConfigs\.getByName\("debug"\)#signingConfig = signingConfigs.getByName("release")#' "$G"
else
  G=android/app/build.gradle
  grep -q 'release {\s*storeFile' "$G" || perl -0pi -e 's#(\n\s*buildTypes\s*\{)#\n    signingConfigs {\n        release {\n            storeFile file(System.getenv("CM_KEYSTORE_PATH"))\n            storePassword System.getenv("CM_KEYSTORE_PASSWORD")\n            keyAlias System.getenv("CM_KEY_ALIAS")\n            keyPassword System.getenv("CM_KEY_PASSWORD")\n        }\n    }\n$1#' "$G"
  perl -pi -e 's#signingConfig signingConfigs\.debug#signingConfig signingConfigs.release#' "$G"
fi
echo "Release signing set"
