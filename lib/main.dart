import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/presentation/view/login_view.dart';
import 'features/trip_optimizer/presentation/viewmodel/trip_optimizer_cubit.dart';
import 'injection_container.dart' as di;

import 'features/trip_optimizer/data/models/spot_model.dart';
import 'features/trip_optimizer/data/models/itinerary_day_model.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/viewmodel/auth_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServices();
  runApp(const TripOptimizerApp());
}

Future<void> _initializeServices() async {
  try {
    // 1. .env yükleniyor
    await dotenv.load(fileName: ".env");
    log("✅ .env başarıyla yüklendi.");

    // 2. Supabase başlatılıyor
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseKey = dotenv.env['SUPABASE_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      log("⚠️ UYARI: Supabase URL veya Key boş!");
    }

    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseKey,
    );
    log("✅ Supabase başlatıldı.");

    // 3. Hive ayarları
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SpotModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ItineraryDayModelAdapter());
    }
    await Hive.openBox('itinerariesBox');
    log("✅ Hive kutusu açıldı.");

    // 4. GetIt Dependency Injection
    await di.init();
    log("✅ GetIt bağımlılıkları yüklendi.");

    // 5. Bildirim Servisi
    try {
      await NotificationService().init();
      log("✅ Bildirim servisi başlatıldı.");
    } catch (e) {
      log("⚠️ Bildirim servisi başlatılamadı: $e");
    }
  } catch (e, stackTrace) {
    log("💥 ANA BAŞLANGIÇ HATASI: $e\n$stackTrace");
    rethrow;
  }
}

class TripOptimizerApp extends StatelessWidget {
  const TripOptimizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Init main()'da tamamlandı, direkt app'i yükle
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthCubit>()),
        BlocProvider(create: (_) => di.sl<TripOptimizerCubit>()),
      ],
      child: MaterialApp(
            title: 'Trip Optimizer',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blueAccent,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              cardColor: const Color(0xFF1E293B),
              dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF1E293B),
              ),
              textTheme: ThemeData.dark().textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintStyle: TextStyle(color: Colors.grey.shade400),
                labelStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                floatingLabelStyle: const TextStyle(color: Colors.blueAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                ),
              ),
            ),
            themeMode: ThemeMode.dark,
            home: const LoginView(),
          ),
    );
  }
}