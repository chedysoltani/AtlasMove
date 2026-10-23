import UIKit
import Flutter
import GoogleMaps
import firebase_messaging

// Cycle de vie par scènes (UIScene), exigé par iOS 27 : sans lui, l'app plante
// au lancement. La scène est créée par FlutterSceneDelegate (Info.plist), et
// les plugins sont enregistrés sur le moteur implicite, après le lancement.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDTxR9EYnaM5ccsM9sW7xnCxtcIKuSB-OY")
    // Les plugins arrivent après ce lancement : Firebase Messaging doit
    // installer ici son délégué de notifications (taps, notifications au
    // premier plan), comme le demande sa documentation pour UIScene.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
