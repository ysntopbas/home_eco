import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Giriş yapan kullanıcının bilgilerini almak için
  User? get currentUser => _auth.currentUser;

  // Kullanıcı oturum durumu değişikliklerini dinlemek için
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Kayıt olma
  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Kullanıcı bilgilerini Firestore'a kaydet
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'id': userCredential.user!.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Giriş yapma
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Çıkış yapma
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Hata yönetimi
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Bu e-posta adresi zaten kullanımda.';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi.';
        case 'weak-password':
          return 'Şifre çok zayıf.';
        case 'user-not-found':
          return 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
        case 'wrong-password':
          return 'Hatalı şifre.';
        default:
          return 'Bir hata oluştu: ${e.message}';
      }
    }
    return 'Beklenmeyen bir hata oluştu.';
  }
}