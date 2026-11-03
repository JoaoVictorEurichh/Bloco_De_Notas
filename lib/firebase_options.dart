// Configuração do Firebase lida de variáveis de compilação (--dart-define).
//
// As chaves NÃO ficam no repositório. Crie o arquivo `firebase.env.json`
// (ignorado pelo Git) a partir de `firebase.env.example.json` e execute:
//
//   flutter run --dart-define-from-file=firebase.env.json
//
// Veja a seção "Configuração do Firebase" do README.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static const _androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.example.blocoDeNotaTurmaa',
  );

  /// `true` quando as variáveis mínimas foram informadas na compilação.
  static bool get isConfigured {
    if (_projectId.isEmpty || _senderId.isEmpty) return false;
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        _androidApiKey.isNotEmpty && _androidAppId.isNotEmpty,
      TargetPlatform.iOS => _iosApiKey.isNotEmpty && _iosAppId.isNotEmpty,
      _ => false,
    };
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
          'Web não é suportada: o armazenamento local usa sqflite.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: _androidApiKey,
          appId: _androidAppId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          storageBucket: _storageBucket,
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: _iosApiKey,
          appId: _iosAppId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          storageBucket: _storageBucket,
          iosBundleId: _iosBundleId,
        );
      default:
        throw UnsupportedError(
            'Plataforma não suportada: use Android ou iOS.');
    }
  }
}
