import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Kullanıcı e-posta ve şifre ile giriş yapar.
  Future<UserEntity> signIn({required String email, required String password});

  /// Yeni kullanıcı kayıt olur.
  Future<UserEntity> signUp({required String email, required String password});

  /// Oturumu kapatır.
  Future<void> signOut();

  /// Şifremi unuttum e-postası gönderir.
  Future<void> resetPassword({required String email});

  /// Cihazda halihazırda giriş yapmış bir kullanıcı ("Beni Hatırla") var mı kontrol eder.
  Future<UserEntity?> getCurrentUser();
}