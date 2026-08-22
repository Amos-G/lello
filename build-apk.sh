#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -x "$ROOT_DIR/.toolchains/jdk/bin/java" ]]; then
  export JAVA_HOME="$ROOT_DIR/.toolchains/jdk"
fi
if [[ -d "$ROOT_DIR/.toolchains/android-sdk/platforms" ]]; then
  export ANDROID_HOME="$ROOT_DIR/.toolchains/android-sdk"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
fi

if [[ -n "${FLUTTER_BIN:-}" ]]; then
  FLUTTER="$FLUTTER_BIN"
elif [[ -x "$ROOT_DIR/.toolchains/flutter/bin/flutter" && \
        -x "$ROOT_DIR/.toolchains/flutter/bin/cache/dart-sdk/bin/dart" ]]; then
  FLUTTER="$ROOT_DIR/.toolchains/flutter/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER="$(command -v flutter)"
elif [[ -x /c/src/flutter/bin/flutter ]]; then
  FLUTTER=/c/src/flutter/bin/flutter
else
  echo "Flutter non trovato. Imposta FLUTTER_BIN con il percorso dell'eseguibile." >&2
  exit 1
fi

KEYSTORE_PASSWORD_FILE="$ROOT_DIR/release/keystore-password.txt"
if [[ ! -r "$ROOT_DIR/release/partysync-release.p12" || ! -r "$KEYSTORE_PASSWORD_FILE" ]]; then
  echo "Keystore release non configurata in $ROOT_DIR/release" >&2
  exit 1
fi
IFS= read -r PARTYSYNC_KEYSTORE_PASSWORD < "$KEYSTORE_PASSWORD_FILE"
export PARTYSYNC_KEYSTORE_PASSWORD

cd "$ROOT_DIR/app"
"$FLUTTER" build apk --release
cp "$ROOT_DIR/app/build/app/outputs/flutter-apk/app-release.apk" "$ROOT_DIR/Lello.apk"
