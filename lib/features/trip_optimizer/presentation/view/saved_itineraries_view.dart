import 'package:flutter/material.dart';
import '../../domain/entities/itinerary_day_entity.dart';
import 'itinerary_view.dart';

class SavedItinerariesView extends StatelessWidget {
  final List<List<ItineraryDayEntity>> savedItineraries;

  const SavedItinerariesView({super.key, required this.savedItineraries});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kayıtlı Rotalarım 📂', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: savedItineraries.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: savedItineraries.length,
        itemBuilder: (context, index) {
          final reverseIndex = savedItineraries.length - 1 - index;
          final itinerary = savedItineraries[reverseIndex];

          final totalDays = itinerary.length;
          final totalPlaces = itinerary.fold<int>(0, (sum, day) => sum + day.places.length);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, // ÇÖZÜM: Sabit beyaz yerine tema rengi!
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map, color: Colors.blueAccent),
              ),
              title: Text(
                'Rota ${reverseIndex + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '$totalDays Günlük Gezi • Toplam $totalPlaces Mekan',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ItineraryView(itinerary: itinerary)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined, size: 80, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Henüz kaydedilmiş bir rotan yok.',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Rota oluşturup sağ alt köşeden kaydedebilirsin.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}