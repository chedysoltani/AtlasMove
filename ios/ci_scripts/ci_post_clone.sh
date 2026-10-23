#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Installer Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# Désactiver Swift Package Manager (incompatibilité du plugin agora_rtc_engine)
flutter config --no-enable-swift-package-manager

flutter precache --ios
flutter pub get

# Installer CocoaPods et les dépendances iOS
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
# --repo-update : index des pods à jour, pour résoudre la dernière version du SDK Facebook (FBSDKCoreKit)
# Podfile.lock ne peut être régénéré que sur un Mac : s'il est périmé (ex. Firebase
# figé en 11.x alors que les plugins exigent 12.x), on le recalcule ici.
cd ios
if ! pod install --repo-update; then
  echo "Podfile.lock incompatible avec les plugins : nouvelle résolution des pods"
  rm -f Podfile.lock
  pod install --repo-update
fi

exit 0
