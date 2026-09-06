// Generated manually from android/app/google-services.json
// (deeppulse-38f3a Firebase project — project_number 668367572887)
//
// Re-generate this file by running `flutterfire configure --project=...`
// once the FlutterFire CLI is installed. Until then, edit by hand.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web. '
        'Run flutterfire configure again to add web support.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS. '
          'Register an iOS app in the Firebase console and re-run '
          'flutterfire configure (or add the values to this file by hand).',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for '
          '$defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPi_uOYHBzzkH2SEdgA8WRlPtzxnoxR44',
    appId: '1:668367572887:android:f3f5fa3b6ec4ae2abdbed2',
    messagingSenderId: '668367572887',
    projectId: 'deeppulse-38f3a',
    storageBucket: 'deeppulse-38f3a.firebasestorage.app',
  );
}
