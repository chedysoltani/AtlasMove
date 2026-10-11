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
cd ios && pod install --repo-update

exit 0
