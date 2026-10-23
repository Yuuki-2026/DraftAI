import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../notes/domain/entities.dart';
import '../../notes/domain/ports.dart';

class GoogleIdentity
    implements
        IdentityService,
        AccountIdentityService,
        ProfilePhotoIdentityService {
  bool _ready = false;
  @override
  bool get configured => _ready;

  @override
  String? get userId => _ready ? FirebaseAuth.instance.currentUser?.uid : null;

  @override
  String? get displayName =>
      _ready ? FirebaseAuth.instance.currentUser?.displayName : null;

  @override
  String? get photoUrl =>
      _ready ? FirebaseAuth.instance.currentUser?.photoURL : null;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      // On Android the google-services Gradle plugin reads the web OAuth
      // client from google-services.json; no client ID is compiled into Dart.
      await GoogleSignIn.instance.initialize();
      _ready = true;
    } catch (_) {
      throw const AppFailure(
        'No se pudo iniciar Firebase. Revisa la configuración de Android y vuelve a intentarlo.',
      );
    }
  }

  @override
  Future<void> signIn() async {
    await initialize();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppFailure('Google no devolvió un token de acceso válido.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'No se pudo iniciar sesión con Google. Revisa la cuenta y la conexión, e inténtalo de nuevo.',
      );
    }
  }

  @override
  Future<String?> idToken() async {
    if (!_ready) return null;
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
