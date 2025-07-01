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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdn7onuCbjcGUDbZ4nVAo8PzR4kFNiyUE',
    appId: '1:677219588060:android:3dd5c1e08e18f8e534a119',
    messagingSenderId: '677219588060',
    projectId: 'semesterup-83f15',
    storageBucket: 'semesterup-83f15.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVc7LSwWdxLh5JCvUqfhtTTOMih-u9qFQ',
    appId: '1:677219588060:ios:9335bdf978e444b134a119',
    messagingSenderId: '677219588060',
    projectId: 'semesterup-83f15',
    storageBucket: 'semesterup-83f15.firebasestorage.app',
    iosBundleId: 'com.example.untitled1',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAW4q9_iYkYG3IVn86T_lyDZJ60ItYMQwM',
    appId: '1:677219588060:web:893b6ea09ef96dd734a119',
    messagingSenderId: '677219588060',
    projectId: 'semesterup-83f15',
    authDomain: 'semesterup-83f15.firebaseapp.com',
    storageBucket: 'semesterup-83f15.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAVc7LSwWdxLh5JCvUqfhtTTOMih-u9qFQ',
    appId: '1:677219588060:ios:5b32e4c42de7224034a119',
    messagingSenderId: '677219588060',
    projectId: 'semesterup-83f15',
    storageBucket: 'semesterup-83f15.firebasestorage.app',
    iosBundleId: 'com.example.flutterProject',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAW4q9_iYkYG3IVn86T_lyDZJ60ItYMQwM',
    appId: '1:677219588060:web:06362d3c1401e34034a119',
    messagingSenderId: '677219588060',
    projectId: 'semesterup-83f15',
    authDomain: 'semesterup-83f15.firebaseapp.com',
    storageBucket: 'semesterup-83f15.firebasestorage.app',
  );

}