// File generated manually to match the flutterfire_cli output shape, from
// the Firebase apps registered under project recette-37d50 (same project as
// the Next.js web app — see ../../.env.local and ../README.md).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCoc0nzpb-v1ArIq7YseoVtg1YC8dPgkOw',
    appId: '1:744435253449:web:54bc46e08803f2e4f40d18',
    messagingSenderId: '744435253449',
    projectId: 'recette-37d50',
    authDomain: 'recette-37d50.firebaseapp.com',
    storageBucket: 'recette-37d50.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBKNhCJ3oKov79GQlv4tJ9PIl5NWMWe3wY',
    appId: '1:744435253449:android:47ef6ced879e5b67f40d18',
    messagingSenderId: '744435253449',
    projectId: 'recette-37d50',
    storageBucket: 'recette-37d50.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCkj6HRqqqNOSb4o9dFwfVQuUYYiBdrRZ0',
    appId: '1:744435253449:ios:b3f4fd31ddcaa72df40d18',
    messagingSenderId: '744435253449',
    projectId: 'recette-37d50',
    storageBucket: 'recette-37d50.firebasestorage.app',
    iosBundleId: 'com.davidmathys.recettesDuTiroir',
  );
}
