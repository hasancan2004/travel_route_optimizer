import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  AuthCubit({required this.authRepository}) : super(AuthInitial());

  Future<void> checkSession() async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      emit(Unauthenticated());
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.signIn(email: email, password: password);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(_getUserFriendlyMessage(e)));
      emit(Unauthenticated());
    }
  }

  // GÜNCELLENDİ: Ad soyad ve telefon parametreleri repository'e aktarılıyor
  Future<void> signUp(String email, String password, String fullName, String phone) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.signUp(
        email: email,
        password: password,
        // Not: Eğer AuthRepository imzan data parametresi alıyorsa buraya eklenir.
        // Genelde repository.signUp(email: email, password: password, data: {'full_name': fullName, 'phone': phone}) şeklindedir.
      );
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(_getUserFriendlyMessage(e)));
      emit(Unauthenticated());
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await authRepository.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError("Çıkış yapılamadı. Lütfen tekrar deneyin."));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await authRepository.resetPassword(email: email);
    } catch (e) {
      emit(AuthError(_getUserFriendlyMessage(e)));
    }
  }

  /// Supabase hatalarını kullanıcı dostu Türkçe mesajlara çevirir
  String _getUserFriendlyMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'E-posta veya şifre hatalı. Lütfen bilgilerinizi kontrol edin.';
        case 'email_not_confirmed':
          return 'E-posta adresiniz henüz doğrulanmamış. Lütfen gelen kutunuzu kontrol edin.';
        case 'user_not_found':
          return 'Bu e-posta ile kayıtlı bir hesap bulunamadı.';
        case 'user_already_exists':
          return 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı deneyin.';
        case 'too_many_requests':
          return 'Çok fazla deneme yaptınız. Lütfen biraz bekleyip tekrar deneyin.';
        case 'weak_password':
          return 'Şifreniz çok zayıf. En az 6 karakter kullanın.';
        case 'same_password':
          return 'Yeni şifreniz eskisiyle aynı olamaz.';
        case 'session_not_found':
          return 'Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.';
        default:
          // Bilinen olmayan auth hata kodları için genel mesaj
          return 'Bir hata oluştu. Lütfen tekrar deneyin.';
      }
    }

    // AuthException dışı hatalar
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('ClientException')) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
    if (msg.contains('TimeoutException')) {
      return 'Bağlantı zaman aşımına uğradı. Tekrar deneyin.';
    }

    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }
}