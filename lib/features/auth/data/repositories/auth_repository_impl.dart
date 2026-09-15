import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> signIn({required String email, required String password}) async {
    return await remoteDataSource.signIn(email: email, password: password);
  }

  @override
  Future<UserEntity> signUp({required String email, required String password}) async {
    return await remoteDataSource.signUp(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<void> resetPassword({required String email}) async {
    await remoteDataSource.resetPassword(email: email);
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }
}