import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- TRIP OPTIMIZER IMPORTLARI ---
import 'features/auth/presentation/viewmodel/auth_cubit.dart';
import 'features/trip_optimizer/data/datasources/trip_remote_data_source.dart';
import 'features/trip_optimizer/data/datasources/trip_local_data_source.dart';
import 'features/trip_optimizer/data/datasources/weather_remote_data_source.dart'; // YENİ: Hava durumu veri kaynağı eklendi
import 'features/trip_optimizer/data/repositories/trip_repository_impl.dart';
import 'features/trip_optimizer/domain/repositories/trip_repository.dart';
import 'features/trip_optimizer/domain/usecases/get_city_spots_usecase.dart';
import 'features/trip_optimizer/domain/usecases/optimize_route_usecase.dart';

// --- YENİ: AUTH IMPORTLARI ---
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/trip_optimizer/presentation/viewmodel/trip_optimizer_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // 1. Dış Paketler (Network & Backend)
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => Supabase.instance.client);

  // ==========================================
  //         TRIP OPTIMIZER INJECTION
  // ==========================================

  // YENİ: WeatherRemoteDataSource GetIt'e kaydedildi
  sl.registerLazySingleton(() => WeatherRemoteDataSource());

  sl.registerLazySingleton<TripRemoteDataSource>(
        () => TripRemoteDataSourceImpl(dio: sl()),
  );

  sl.registerLazySingleton<TripLocalDataSource>(
        () => TripLocalDataSourceImpl(),
  );

  sl.registerLazySingleton<TripRepository>(
        () => TripRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      weatherRemoteDataSource: sl(), // YENİ: Enjeksiyon tamamlandı
    ),
  );

  sl.registerLazySingleton(() => GetCitySpotsUseCase(sl()));
  sl.registerLazySingleton(() => OptimizeRouteUseCase(sl()));

  sl.registerFactory(
        () => TripOptimizerCubit(
      getCitySpotsUseCase: sl(),
      optimizeRouteUseCase: sl(),
      repository: sl(),
    ),
  );

  // ==========================================
  //              AUTH INJECTION
  // ==========================================

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(supabaseClient: sl()),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // Cubit
  sl.registerFactory(
        () => AuthCubit(authRepository: sl()),
  );
}