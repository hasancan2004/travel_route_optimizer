import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  AuthCubit({required this.authRepository}) : super(AuthInitial());

  // UYGULAMA AÇILDIĞINDA ÇALIŞIR: "Beni Hatırla" Mantığı
  Future<void> checkSession() async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(Authenticated(user)); // Eski oturum bulundu, direkt içeri al
      } else {
        emit(Unauthenticated()); // Oturum yok, login ekranına at
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
      emit(AuthError(e.toString().replaceAll("Exception: ", "")));
      emit(Unauthenticated()); // Hatayı gösterdikten sonra tekrar Login ekranında bekle
    }
  }

  Future<void> signUp(String email, String password) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.signUp(email: email, password: password);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll("Exception: ", "")));
      emit(Unauthenticated());
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await authRepository.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError("Çıkış yapılamadı: $e"));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await authRepository.resetPassword(email: email);
      // Şifre sıfırlamada state'i tamamen değiştirmeyiz, view katmanında sadece bir SnackBar gösteririz.
    } catch (e) {
      emit(AuthError(e.toString().replaceAll("Exception: ", "")));
    }
  }
}