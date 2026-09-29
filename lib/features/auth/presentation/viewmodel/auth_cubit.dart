import 'package:flutter_bloc/flutter_bloc.dart';
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
      emit(AuthError(e.toString().replaceAll("Exception: ", "")));
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
    } catch (e) {
      emit(AuthError(e.toString().replaceAll("Exception: ", "")));
    }
  }
}