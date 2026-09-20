import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // YENİ: Supabase eklendi
import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    // Verileri sessizce çekmek için loadTravelerStats kullanıyoruz
    context.read<TripOptimizerCubit>().loadTravelerStats();
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: Oturum açmış kullanıcıyı Supabase'den dinamik olarak çekiyoruz
    final currentUser = Supabase.instance.client.auth.currentUser;
    final String displayName = currentUser?.userMetadata?['full_name'] ??
        (currentUser?.email?.split('@').first ?? 'Gizemli Gezgin');

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text('Profilim', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<TripOptimizerCubit, TripOptimizerState>(
        builder: (context, state) {
          double totalWalkedKm = 0.0;
          int totalTrips = 0;

          if (state is TravelerStatsLoaded) {
            final itineraries = state.itineraries;
            totalTrips = itineraries.length;

            for (var itinerary in itineraries) {
              for (var day in itinerary) {
                totalWalkedKm += day.estimatedWalkingKm;
              }
            }
          }

          // Seviye Hesaplama (Her 15 km'de bir seviye atlama)
          int currentLevel = (totalWalkedKm / 15).floor() + 1;
          double currentLevelProgress = totalWalkedKm % 15;
          double progressPercentage = currentLevelProgress / 15.0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profil Kartı
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.blueAccent, Colors.deepPurpleAccent.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 50,
                          backgroundColor: Color(0xFF1E293B),
                          child: Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        // YENİ: Dinamik isim
                        displayName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // YENİ: Dinamik seviye unvanı
                        'Seviye $currentLevel Gezgini',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Seviye Çubuğu
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Seviye $currentLevel',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${currentLevelProgress.toStringAsFixed(1)} / 15 km',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressPercentage,
                          minHeight: 12,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sonraki seviyeye ulaşmak için ${(15 - currentLevelProgress).toStringAsFixed(1)} km daha yürümelisin!',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Kazanılan Başarımlar Başlığı
                const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Fiziksel Aktiviteler',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dinamik Rozet Izgarası
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _buildBadgeCard('Isınma Turu 🥉', '5 km barajını geçtin. Yürüyüşe yeni başlıyoruz!', totalWalkedKm >= 5, Colors.orangeAccent),
                    _buildBadgeCard('Şehir Kaşifi 🥈', '15 km aşıldı! Sokaklar senden soruluyor.', totalWalkedKm >= 15, Colors.blueAccent),
                    _buildBadgeCard('Yorulmaz Gezgin 🥇', '30 km devrildi! İnanılmaz bir kondisyon.', totalWalkedKm >= 30, Colors.deepPurpleAccent),
                    _buildBadgeCard('Koşu Bandı Şampiyonu 🏃', '50 km hedefini aştın. Harika bir kardiyo!', totalWalkedKm >= 50, Colors.greenAccent),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadgeCard(String title, String description, bool isUnlocked, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? color.withOpacity(0.15) : cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? color.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUnlocked ? Icons.verified : Icons.lock_outline,
            color: isUnlocked ? color : Colors.white24,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isUnlocked ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isUnlocked ? Colors.grey.shade300 : Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}