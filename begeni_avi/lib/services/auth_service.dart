import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import 'db.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static bool _googleReady = false;

  static Future<void> signInWithGoogle() async {
    if (!AppConfig.googleConfigured) {
      throw Exception('Google ile giriş henüz açılmadı, şimdilik e-posta ile devam et.');
    }
    final gs = GoogleSignIn.instance;
    if (!_googleReady) {
      await gs.initialize(serverClientId: AppConfig.googleWebClientId);
      _googleReady = true;
    }
    final account = await gs.authenticate();
    final idToken = account.authentication.idToken;
    final cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    final u = cred.user!;
    await Db.ensureUser(u.uid, u.displayName ?? account.displayName ?? 'Oyuncu', u.photoURL ?? '');
  }

  static Future<void> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    final u = cred.user!;
    await Db.ensureUser(u.uid, u.displayName ?? email.split('@').first, u.photoURL ?? '');
  }

  static Future<void> register(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user!.updateDisplayName(name.trim());
    await Db.ensureUser(cred.user!.uid, name.trim(), '');
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-posta adresi geçersiz.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-posta ya da şifre yanlış.';
        case 'email-already-in-use':
          return 'Bu e-posta ile zaten hesap var, giriş yap.';
        case 'weak-password':
          return 'Şifre en az 6 karakter olmalı.';
        case 'network-request-failed':
          return 'İnternet bağlantısı yok.';
      }
      return e.message ?? e.code;
    }
    if (e is GoogleSignInException) {
      if (e.code == GoogleSignInExceptionCode.canceled) return 'Google girişi iptal edildi.';
      return 'Google girişi başarısız: ${e.description ?? e.code.name}';
    }
    return '$e'.replaceFirst('Exception: ', '');
  }
}
