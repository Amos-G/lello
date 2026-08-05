#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JAVA_HOME="$ROOT_DIR/.toolchains/jdk"
export ANDROID_HOME="$ROOT_DIR/.toolchains/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

KEYSTORE_PASSWORD_FILE="$ROOT_DIR/release/keystore-password.txt"
if [[ ! -r "$ROOT_DIR/release/partysync-release.p12" || ! -r "$KEYSTORE_PASSWORD_FILE" ]]; then
  echo "Keystore release non configurata in $ROOT_DIR/release" >&2
  exit 1
fi
IFS= read -r PARTYSYNC_KEYSTORE_PASSWORD < "$KEYSTORE_PASSWORD_FILE"
export PARTYSYNC_KEYSTORE_PASSWORD

cd "$ROOT_DIR/app"
"$ROOT_DIR/.toolchains/flutter/bin/flutter" build apk --release
cp "$ROOT_DIR/app/build/app/outputs/flutter-apk/app-release.apk" "$ROOT_DIR/Lello.apk"
