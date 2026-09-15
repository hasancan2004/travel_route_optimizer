import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/entities/user_entity.dart';
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
  });

  // Supabase'den gelen karmaşık User objesini, bizim sade nesnemize çevirir.
  factory UserModel.fromSupabase(supabase.User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? "",
    );
  }
}