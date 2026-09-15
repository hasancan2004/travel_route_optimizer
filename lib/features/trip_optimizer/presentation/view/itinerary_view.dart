import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travel_route_optimizer/features/trip_optimizer/presentation/view/pdf_preview_view.dart';

import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';

import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';
import 'budget_assistant_view.dart';
import 'day_map_view.dart';
import '../../data/datasources/weather_remote_data_source.dart';
import '../../data/models/weather_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ItineraryView extends StatefulWidget {
  final List<ItineraryDayEntity> itinerary;
  final List<Map<String, String>> availableCategories;

  const ItineraryView({
    super.key,
    required this.itinerary,
    this.availableCategories = const [
      {'label': 'Tarih 🏛️', 'value': 'history'},
      {'label': 'Doğa 🌲', 'value': 'nature'},
      {'label': 'Alışveriş 🛍️', 'value': 'shopping'},
      {'label': 'Yemek 🍔', 'value': 'food'},
    ],
  });

  @override
  State<ItineraryView> createState() => _ItineraryViewState();
}

class _ItineraryViewState extends State<ItineraryView> {
  late List<ItineraryDayEntity> _localItinerary;

  @override
  void initState() {
    super.initState();
    _localItinerary = widget.itinerary.map((day) {
      return ItineraryDayEntity(
        day: day.day,
        places: List<SpotEntity>.from(day.places),
        estimatedWalkingKm: day.estimatedWalkingKm,
      );
    }).toList();

    _autoSave();
  }

  void _autoSave() {
    context.read<TripOptimizerCubit>().autoSaveItinerary(_localItinerary);
  }

  void _shareItinerary() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('🗺️ **Trip Optimizer Seyahat Rotam** 🚀\n');

    for (var dayPlan in _localItinerary) {
      buffer.writeln('📅 **${dayPlan.day}. Gün** (Tahmini Yürüyüş: ${dayPlan.estimatedWalkingKm.toStringAsFixed(1)} km)');
      if (dayPlan.places.isEmpty) {
        buffer.writeln('   • Henüz mekan eklenmedi.');
      } else {
        for (int i = 0; i < dayPlan.places.length; i++) {
          final spot = dayPlan.places[i];
          final feeText = spot.entryFee > 0 ? '${spot.entryFee} ₺' : 'Ücretsiz';
          buffer.writeln('   ${i + 1}. ${spot.name} (${spot.category.toUpperCase()}) - $feeText');
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('✨ Bu harika rota TripOptimizer ile hazırlandı!');

    Share.share(buffer.toString(), subject: 'Seyahat Rotam 🗺️');
  }

  void _showAddCustomSpotModal(BuildContext context, int dayIndex) {
    LatLng initialMapCenter = const LatLng(36.8969, 30.7133); // En son çare Antalya

    if (_localItinerary[dayIndex].places.isNotEmpty) {
      initialMapCenter = LatLng(
          _localItinerary[dayIndex].places.first.lat,
          _localItinerary[dayIndex].places.first.lng
      );
    } else {
      for (var day in _localItinerary) {
        if (day.places.isNotEmpty) {
          initialMapCenter = LatLng(day.places.first.lat, day.places.first.lng);
          break;
        }
      }
    }

    Navigator.of(this.context).push<SpotEntity>(
      MaterialPageRoute(
        builder: (_) => _AddSpotFullScreen(
          dayIndex: dayIndex,
          availableCategories: widget.availableCategories,
          initialMapCenter: initialMapCenter,
        ),
      ),
    ).then((newSpot) {
      if (newSpot != null && mounted) {
        setState(() {
          _localItinerary[dayIndex].places.add(newSpot);
        });
        _autoSave();

        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Text('Yeni mekan rotaya eklendi! ✨'),
            backgroundColor: Colors.blueAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        // ÇÖZÜM: Başlık metni kısaltılarak ikonlarla çakışması ve kesilmesi engellendi
        title: const Text(
          'Seyahat Rotam 🗺️',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 22),
            tooltip: "Toplulukta Paylaş",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  final titleController = TextEditingController(text: "Harika Bir Seyahat Rotası");
                  return AlertDialog(
                    title: const Text("Rotayı Toplulukta Paylaş 🌍"),
                    content: TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Rota Başlığı"),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("İptal"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<TripOptimizerCubit>().shareItinerary(
                            title: titleController.text,
                            itinerary: _localItinerary,
                          );
                        },
                        child: const Text("Paylaş"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 24),
            tooltip: 'PDF Oluştur / Paylaş',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfPreviewView(itinerary: _localItinerary),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, size: 24),
            tooltip: 'Bütçe Asistanı',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetAssistantView(itinerary: _localItinerary),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocListener<TripOptimizerCubit, TripOptimizerState>(
        listener: (context, state) {
          if (state is ItinerarySaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rota Başarıyla Kaydedildi! 💾'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is TripOptimizerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          // ÇÖZÜM: Listenin alt boşluğu artırılarak butonların rahat sığması sağlandı
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 120.0),
          itemCount: _localItinerary.length + 1,
          itemBuilder: (context, index) {
            if (index == _localItinerary.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
                child: Column(
                  children: [
                    // Yeni Gün Ekle Butonu
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _localItinerary.add(
                            ItineraryDayEntity(
                              day: _localItinerary.length + 1,
                              places: [],
                              estimatedWalkingKm: 0.0,
                            ),
                          );
                        });
                        _autoSave();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Yeni gün eklendi! 🎉 Kendi mekanlarını ekleyebilirsin.'),
                            backgroundColor: Colors.blueAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.white38, width: 1.5),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.calendar_month, size: 24),
                      label: const Text(
                        'Yeni Gün Ekle 📅',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ÇÖZÜM: Rotayı Kaydet butonu FAB yerinden alınıp buraya, Yeni Gün'ün altına eklendi (Çakışma bitti!)
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<TripOptimizerCubit>().saveItinerary(_localItinerary);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.save, size: 24),
                      label: const Text(
                        'Rotayı Kaydet 💾',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }

            final dayPlan = _localItinerary[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade800, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  '${dayPlan.day}. Gün',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (dayPlan.places.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 24,
                                    width: 1,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(width: 10),
                                  DayWeatherBadge(
                                    lat: dayPlan.places.first.lat,
                                    lng: dayPlan.places.first.lng,
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DayMapView(dayPlan: dayPlan),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map_outlined, color: Colors.white),
                              tooltip: 'Haritada Gör',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_walk, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${dayPlan.estimatedWalkingKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  dayPlan.places.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'Bu gün için henüz mekan eklemedin.',
                        style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                      : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: dayPlan.places.length,
                    onReorder: (int oldIndex, int newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final SpotEntity item = dayPlan.places.removeAt(oldIndex);
                        dayPlan.places.insert(newIndex, item);
                      });
                      _autoSave();
                    },
                    itemBuilder: (context, spotIndex) {
                      final spot = dayPlan.places[spotIndex];

                      return Dismissible(
                        key: ValueKey(spot.name + spotIndex.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          color: Colors.red.shade400,
                          child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
                        ),
                        onDismissed: (direction) {
                          setState(() {
                            dayPlan.places.removeAt(spotIndex);
                          });
                          _autoSave();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${spot.name} rotadan çıkarıldı! 🗑️'),
                              backgroundColor: Colors.black87,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: ListTile(
                          key: ValueKey('list_tile_${spot.name}_$spotIndex'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: spot.imagePath != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(spot.imagePath!),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCategoryIcon(spot.category),
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            '${spotIndex + 1}. ${spot.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Row(
                              children: [
                                Text(
                                  spot.category.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  spot.rating.toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: spot.entryFee > 0 ? Colors.grey.shade100 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  spot.entryFee > 0 ? '${spot.entryFee} ₺' : 'Ücretsiz',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: spot.entryFee > 0 ? Colors.black87 : Colors.green.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
                    child: TextButton.icon(
                      onPressed: () => _showAddCustomSpotModal(context, index),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Kendi Mekanını Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      // Çakışmaya sebep olan FloatingActionButton tamamen kaldırıldı.
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'history':
        return Icons.account_balance;
      case 'shopping':
        return Icons.shopping_bag;
      case 'nature':
        return Icons.park;
      case 'food':
        return Icons.restaurant;
      default:
        return Icons.place;
    }
  }
}

class DayWeatherBadge extends StatefulWidget {
  final double lat;
  final double lng;

  const DayWeatherBadge({super.key, required this.lat, required this.lng});

  @override
  State<DayWeatherBadge> createState() => _DayWeatherBadgeState();
}

class _DayWeatherBadgeState extends State<DayWeatherBadge> {
  WeatherModel? _weather;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final dataSource = WeatherRemoteDataSource();
    final weather = await dataSource.getWeather(widget.lat, widget.lng);

    if (mounted) {
      setState(() {
        _weather = weather;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    if (_weather == null) return const SizedBox.shrink();

    return Row(
      children: [
        Image.network(
          'https://openweathermap.org/img/wn/${_weather!.iconCode}.png',
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 4),
        Text(
          '${_weather!.temperature.round()}°C',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _AddSpotFullScreen extends StatefulWidget {
  final int dayIndex;
  final List<Map<String, String>> availableCategories;
  final LatLng initialMapCenter;

  const _AddSpotFullScreen({
    required this.dayIndex,
    required this.availableCategories,
    required this.initialMapCenter,
  });

  @override
  State<_AddSpotFullScreen> createState() => _AddSpotFullScreenState();
}

class _AddSpotFullScreenState extends State<_AddSpotFullScreen> {
  final _nameController = TextEditingController();
  final _feeController = TextEditingController();
  final _searchController = TextEditingController();

  late String _selectedCategory;

  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();

    _selectedCategory = widget.availableCategories.isNotEmpty
        ? widget.availableCategories.first['value']!
        : 'custom';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    if (mounted) {
      setState(() => _locationPermissionGranted = true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
      );
    }
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen mekan adını girin.')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen haritada bir konum seçin.')),
      );
      return;
    }

    final spot = SpotEntity(
      name: name,
      category: _selectedCategory,
      rating: 5.0,
      entryFee: double.tryParse(_feeController.text) ?? 0.0,
      lat: _selectedLocation!.latitude,
      lng: _selectedLocation!.longitude,
      imagePath: _selectedImagePath,
    );

    Navigator.of(context).pop(spot);
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBg = Color(0xFF0F172A);
    const Color cardBg = Color(0xFF1E293B);
    const Color inputBg = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text('Yeni Mekan Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cardBg,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: _selectedImagePath != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_selectedImagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo_rounded, size: 32, color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Kapak Fotoğrafı Ekle',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Galeriden seçmek için dokunun',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Mekan Adı',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.place_outlined, color: Colors.blueAccent),
                            filled: true,
                            fillColor: inputBg,
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          dropdownColor: cardBg,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.category_outlined, color: Colors.blueAccent),
                            filled: true,
                            fillColor: inputBg,
                          ),
                          items: widget.availableCategories.isNotEmpty
                              ? widget.availableCategories.map((cat) {
                            return DropdownMenuItem(
                              value: cat['value'],
                              child: Text(cat['label']!),
                            );
                          }).toList()
                              : const [DropdownMenuItem(value: 'custom', child: Text('Özel Kategori 📌'))],
                          onChanged: (value) {
                            setState(() => _selectedCategory = value!);
                          },
                        ),

                        const SizedBox(height: 16),
                        TextField(
                          controller: _feeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Tahmini Ücret (TL)',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.blueAccent),
                            filled: true,
                            fillColor: inputBg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedLocation != null ? Colors.green.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedLocation != null ? Colors.green : Colors.blueAccent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedLocation != null ? Icons.check_circle : Icons.touch_app,
                          color: _selectedLocation != null ? Colors.greenAccent : Colors.blueAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedLocation != null
                                ? 'Konum Onaylandı: ${_selectedLocation!.latitude.toStringAsFixed(3)}, ${_selectedLocation!.longitude.toStringAsFixed(3)}'
                                : 'Konum seçmek için haritada özgürce gezinin ve dokunun',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedLocation != null ? Colors.greenAccent : Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    height: 350,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBg, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: widget.initialMapCenter,
                            zoom: 13,
                          ),
                          onMapCreated: (c) => _mapController = c,
                          onTap: (pos) {
                            FocusScope.of(context).unfocus();
                            setState(() => _selectedLocation = pos);
                          },
                          gestureRecognizers: {
                            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                          },
                          markers: _selectedLocation != null
                              ? {
                            Marker(
                              markerId: const MarkerId('pick'),
                              position: _selectedLocation!,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                            ),
                          }
                              : {},
                          myLocationEnabled: _locationPermissionGranted,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),

                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBg.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _onSearchPlace,
                              decoration: InputDecoration(
                                hintText: 'Haritada yer ara...',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    FocusScope.of(context).unfocus();
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            heroTag: 'findMe2',
                            backgroundColor: cardBg,
                            onPressed: () async {
                              try {
                                final pos = await Geolocator.getCurrentPosition();
                                final target = LatLng(pos.latitude, pos.longitude);
                                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
                                setState(() => _selectedLocation = target);
                              } catch (_) {}
                            },
                            child: const Icon(Icons.my_location, size: 20, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _confirm,
                  child: const Text(
                    'Mekanı Rotaya Ekle',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSearchPlace(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$query" aranıyor... 🔍'),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final String googleApiKey = dotenv.env["GOOGLE_PLACES_API_KEY"] ?? "";

      if (googleApiKey.isEmpty) {
        throw Exception("API Key bulunamadı! Lütfen .env dosyanızı kontrol edin.");
      }

      final String url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception("Google sunucularına ulaşılamadı (Hata: ${response.statusCode})");
      }

      final data = json.decode(response.body);
      final status = data['status'];

      if (status == 'OK' && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        final target = LatLng(location['lat'], location['lng']);

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 14));

        setState(() {
          _selectedLocation = target;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum bulundu ve işaretlendi! 📍'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      else if (status == 'ZERO_RESULTS') {
        throw Exception("Böyle bir yer bulunamadı. Yazımı kontrol edin.");
      }
      else if (status == 'REQUEST_DENIED') {
        final errorMessage = data['error_message'] ?? 'Bilinmeyen sebep';
        print("GOOGLE REDDETTİ: $errorMessage");
        throw Exception("API Reddedildi: Geocoding aktif olmayabilir.\nDetay: $errorMessage");
      }
      else if (status == 'OVER_QUERY_LIMIT') {
        throw Exception("API kullanım kotanız dolmuş.");
      }
      else if (status == 'INVALID_REQUEST') {
        throw Exception("Geçersiz istek atıldı.");
      }
      else {
        throw Exception("Google API Hatası: $status");
      }
    } catch (e) {
      String errorText = e.toString().replaceAll("Exception: ", "");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorText),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      print("ARAMA FONKSİYONU PATLADI: $e");
    }
  }
}