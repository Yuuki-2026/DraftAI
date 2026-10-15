import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';

class GoogleIdentity implements IdentityService {
  bool _ready = false;
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  @override
  bool get configured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      projectId.isNotEmpty &&
      senderId.isNotEmpty;
  Future<void> _initialize() async {
    if (_ready) return;
    if (!configured) {
      throw const AppFailure(
        'Google aún no está configurado. Puedes continuar sin cuenta.',
      );
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      ),
    );
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _ready = true;
  }

  @override
  String? get displayName =>
      _ready ? FirebaseAuth.instance.currentUser?.displayName : null;
  @override
  Future<void> signIn() async {
    await _initialize();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (_) {
      throw const AppFailure(
        'No se pudo iniciar sesión con Google. Puedes reintentar o continuar sin cuenta.',
      );
    }
  }

  @override
  Future<String?> idToken() async {
    if (!configured) return null;
    await _initialize();
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  @override
  Future<void> signOut() async {
    if (_ready) {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
    }
  }
}
