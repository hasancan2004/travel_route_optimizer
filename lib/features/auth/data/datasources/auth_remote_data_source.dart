import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_route_optimizer/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signIn({required String email, required String password});
  Future<UserModel> signUp({required String email, required String password});
  Future<void> signOut();
  Future<void> resetPassword({required String email});
  Future<UserModel?> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;

  AuthRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<UserModel?> getCurrentUser() async {
    // Kullanıcı uygulamayı kapatıp açsa bile Supabase token'ı hafızada tutar.
    // Eğer geçerli bir oturum varsa direkt kullanıcıyı döndürürüz ("Beni Hatırla" mantığı).
    final user = supabaseClient.auth.currentUser;
    if (user != null) {
      return UserModel.fromSupabase(user);
    }
    return null;
  }

  @override
  Future<void> resetPassword({required String email}) async {
    // Supabase bu adrese otomatik şifre sıfırlama linki yollar
    await supabaseClient.auth.resetPasswordForEmail(email);
  }

  @override
  Future<UserModel> signIn({required String email, required String password}) async {
    final response = await supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Giriş yapılamadı, bilgilerinizi kontrol edin.');
    return UserModel.fromSupabase(response.user!);
  }

  @override
  Future<void> signOut() async {
    await supabaseClient.auth.signOut();
  }

  @override
  Future<UserModel> signUp({required String email, required String password}) async {
    final response = await supabaseClient.auth.signUp(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Kayıt işlemi başarısız oldu.');
    return UserModel.fromSupabase(response.user!);
  }
}