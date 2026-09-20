import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/itinerary_day_entity.dart';
import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';

class ExploreDetailView extends StatelessWidget {
  final String title;
  final String city;
  final String author;
  final double budget;
  final List<ItineraryDayEntity> itinerary;

  const ExploreDetailView({
    Key? key,
    required this.title,
    required this.city,
    required this.author,
    required this.budget,
    required this.itinerary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // BlocListener ile durumları dinleyip başarılı/başarısız mesajlarını gösteriyoruz
    return BlocListener<TripOptimizerCubit, TripOptimizerState>(
      listener: (context, state) {
        if (state is ItinerarySaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Rota başarıyla Kayıtlı Rotalarına kopyalandı!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is TripOptimizerError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${state.message}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Üst Bilgi Kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(city.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.black26,
                      ),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            "${budget.toStringAsFixed(0)} ₺",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Yazan: $author",
                    style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Günlük Rota Planı 📅",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Günler Listesi
            if (itinerary.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text("Bu rotaya ait gün detay bulunamadı.", style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...itinerary.map((dayPlan) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(
                      "${dayPlan.day}. Gün Planı",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: Text(
                      "Tahmini Yürüyüş: ${dayPlan.estimatedWalkingKm.toStringAsFixed(1)} km",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    iconColor: Colors.deepPurpleAccent,
                    collapsedIconColor: Colors.grey,
                    children: dayPlan.places.isEmpty
                        ? [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("Bu güne mekan eklenmemiş.", style: TextStyle(color: Colors.grey)),
                      )
                    ]
                        : dayPlan.places.asMap().entries.map((entry) {
                      final index = entry.key;
                      final spot = entry.value;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade900,
                          child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                        title: Text(spot.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text("${spot.category.toUpperCase()} • ⭐ ${spot.rating}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        trailing: Text(
                          spot.entryFee > 0 ? "${spot.entryFee} ₺" : "Ücretsiz",
                          style: TextStyle(
                            color: spot.entryFee > 0 ? Colors.orangeAccent : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            const SizedBox(height: 80), // FAB butonunun listeyi kapatmaması için altta boşluk
          ],
        ),

        // YENİ: Rotayı Kendime Ekle Butonu
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: BlocBuilder<TripOptimizerCubit, TripOptimizerState>(
          builder: (context, state) {
            final isLoading = state is TripOptimizerLoading;
            return FloatingActionButton.extended(
              onPressed: isLoading
                  ? null
                  : () {
                final cubit = context.read<TripOptimizerCubit>();
                // Cubit içindeki state'i bu rotanın özelliklerine göre manipüle ediyoruz
                cubit.currentCity = city;
                cubit.updateBudget(budget);

                // Kaydetme işlemini tetikliyoruz
                cubit.saveItinerary(itinerary);
              },
              backgroundColor: isLoading ? Colors.grey.shade700 : Colors.deepPurpleAccent,
              icon: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.library_add, color: Colors.white),
              label: Text(
                isLoading ? "Kopyalanıyor..." : "Rotayı Kendime Ekle",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            );
          },
        ),
      ),
    );
  }
}