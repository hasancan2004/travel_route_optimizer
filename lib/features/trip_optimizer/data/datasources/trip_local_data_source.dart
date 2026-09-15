import 'package:hive/hive.dart';
import '../models/itinerary_day_model.dart';

abstract class TripLocalDataSource {
  Future<void> saveItinerary(List<ItineraryDayModel> itinerary);
  Future<List<List<ItineraryDayModel>>> getSavedItineraries();
}

class TripLocalDataSourceImpl implements TripLocalDataSource {
  // main.dart'ta açtığımız kutuyu referans alıyoruz
  final Box _itinerariesBox = Hive.box('itinerariesBox');

  @override
  Future<void> saveItinerary(List<ItineraryDayModel> itinerary) async {
    // Rotayı veritabanına ekliyoruz. add() metodu otomatik olarak yeni bir ID atar.
    await _itinerariesBox.add(itinerary);
  }

  @override
  Future<List<List<ItineraryDayModel>>> getSavedItineraries() async {
    // Kutudaki tüm kayıtlı rotaları çekip listeye dönüştürüyoruz
    final List<List<ItineraryDayModel>> savedItineraries = [];

    for (var i = 0; i < _itinerariesBox.length; i++) {
      final item = _itinerariesBox.getAt(i);
      if (item != null) {
        // Hive'dan dönen dynamic veriyi kendi modelimize cast (dönüştürme) ediyoruz
        savedItineraries.add(List<ItineraryDayModel>.from(item));
      }
    }

    return savedItineraries;
  }
}