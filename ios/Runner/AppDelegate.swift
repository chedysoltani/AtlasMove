import UIKit
import Flutter
import GoogleMaps

// Cycle de vie par scènes (UIScene), obligatoire avec le SDK iOS 27.1 : sans
// lui, l'app plante au lancement. La scène est créée par FlutterSceneDelegate
// (Info.plist), et les plugins sont enregistrés sur le moteur implicite.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDTxR9EYnaM5ccsM9sW7xnCxtcIKuSB-OY")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
