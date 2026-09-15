import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';
import 'explore_detail_view.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    // Ekran açılır açılmaz topluluk rotalarını çekiyoruz
    context.read<TripOptimizerCubit>().exploreItineraries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gezginler Keşfet 🌍"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<TripOptimizerCubit, TripOptimizerState>(
        listener: (context, state) {
          if (state is TripOptimizerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is TripOptimizerLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PublicItinerariesLoaded) {
            final itineraries = state.publicItineraries;

            if (itineraries.isEmpty) {
              return const Center(
                child: Text(
                  "Henüz toplulukta paylaşılan bir rota yok.\nİlk rotayı sen paylaş! 🚀",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: itineraries.length,
              itemBuilder: (context, index) {
                final item = itineraries[index];
                final city = item['city'] ?? 'Bilinmeyen Şehir';
                final title = item['title'] ?? 'Harika Bir Seyahat';
                final author = item['author_name'] ?? 'Gezgin';
                final budget = (item['total_budget'] ?? 0.0).toDouble();
                final createdAt = item['created_at']?.toString().substring(0, 10) ?? '';

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(city.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.deepPurple,
                            ),
                            Text(
                              createdAt,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Yazar: $author",
                          style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, size: 18, color: Colors.green),
                                const SizedBox(width: 4),
                                Text("Bütçe: ${budget.toStringAsFixed(0)} ₺", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                // BURASI DEĞİŞTİ: Veritabanındaki gerçek kolon adını okuyoruz
                                final rawItinerary = item['route_json'];

                                debugPrint("--- İNCELE TIKLANDI ---");
                                debugPrint("Gelen Ham Route Verisi: $rawItinerary");
                                debugPrint("Veri Tipi: ${rawItinerary.runtimeType}");

                                List<dynamic> itineraryDaysJson = [];

                                if (rawItinerary is List) {
                                  itineraryDaysJson = rawItinerary;
                                } else if (rawItinerary is String) {
                                  try {
                                    final decoded = jsonDecode(rawItinerary);
                                    if (decoded is List) {
                                      itineraryDaysJson = decoded;
                                    }
                                  } catch (e) {
                                    debugPrint("JSON decode hatası: $e");
                                  }
                                } else if (rawItinerary is Map) {
                                  itineraryDaysJson = [rawItinerary];
                                }

                                // JSON verisini güvenli bir şekilde ItineraryDayEntity listesine dönüştürüyoruz
                                List<ItineraryDayEntity> parsedItinerary = [];

                                try {
                                  parsedItinerary = itineraryDaysJson.map((dayJson) {
                                    final dayMap = dayJson as Map<String, dynamic>;
                                    final dayNumber = dayMap['day'] ?? 1;
                                    final walkingKm = (dayMap['estimatedWalkingKm'] ?? 0.0).toDouble();

                                    final placesJson = dayMap['places'] as List<dynamic>? ?? [];
                                    List<SpotEntity> parsedSpots = placesJson.map((spotJson) {
                                      final spotMap = spotJson as Map<String, dynamic>;
                                      return SpotEntity(
                                        name: spotMap['name'] ?? 'Bilinmeyen Mekan',
                                        category: spotMap['category'] ?? 'custom',
                                        rating: (spotMap['rating'] ?? 3.0).toDouble(),
                                        entryFee: (spotMap['entryFee'] ?? 0.0).toDouble(),
                                        lat: (spotMap['lat'] ?? 0.0).toDouble(),
                                        lng: (spotMap['lng'] ?? 0.0).toDouble(),
                                        imagePath: spotMap['imagePath'],
                                      );
                                    }).toList();

                                    return ItineraryDayEntity(
                                      day: dayNumber,
                                      places: parsedSpots,
                                      estimatedWalkingKm: walkingKm,
                                    );
                                  }).toList();
                                } catch (parseError) {
                                  debugPrint("Itinerary parse edilirken kritik hata: $parseError");
                                }

                                debugPrint("Parse edilen gün sayısı: ${parsedItinerary.length}");

                                // Detay ekranına yönlendiriyoruz
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExploreDetailView(
                                      title: title,
                                      city: city,
                                      author: author,
                                      budget: budget,
                                      itinerary: parsedItinerary,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text("İncele"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}