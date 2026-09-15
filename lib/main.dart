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
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_KEY'] ?? '',
  );

  await Hive.initFlutter();
  Hive.registerAdapter(SpotModelAdapter());
  Hive.registerAdapter(ItineraryDayModelAdapter());
  await Hive.openBox('itinerariesBox');

  await di.init();

  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          dialogBackgroundColor: const Color(0xFF1E293B),

          // Metinlerin genel rengini beyaza sabitliyoruz ki listeler/kartlar okunur olsun
          textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),

          // Input alanlarındaki etiketlerin kaybolmaması için renk ve border ayarları
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