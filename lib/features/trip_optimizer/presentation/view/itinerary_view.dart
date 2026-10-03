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
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_route_optimizer/features/trip_optimizer/presentation/view/pdf_preview_view.dart';

import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';

import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';
import 'budget_assistant_view.dart';
import 'day_map_view.dart';
import 'smart_packing_view.dart';
import '../../data/datasources/weather_remote_data_source.dart';
import '../../data/models/weather_model.dart';
import 'package:travel_route_optimizer/core/services/fuel_price_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ItineraryView extends StatefulWidget {
  final List<ItineraryDayEntity> itinerary;
  final double maxBudget;
  final List<Map<String, String>> availableCategories;

  const ItineraryView({
    super.key,
    required this.itinerary,
    this.maxBudget = 5000.0,
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
    final cubit = context.read<TripOptimizerCubit>();
    cubit.autoSaveItinerary(_localItinerary);

    cubit.checkBudgetWithML(_localItinerary);
  }

  double get _totalSpent {
    return _localItinerary.fold(0.0, (sum, day) {
      return sum + day.places.fold(0.0, (daySum, spot) => daySum + spot.entryFee);
    });
  }

  Future<void> _launchMaps(double lat, double lng, String spotName) async {
    final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$spotName için haritalar açılamadı!'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

  // ==========================================
  // GÜNCELLENEN: ÖZEL ARAÇ GİRİŞ FORMU
  // ==========================================
  void _showVehicleSelectionModal(BuildContext context) {
    final cubit = context.read<TripOptimizerCubit>();
    String selectedFuelType = 'gasoline';
    final TextEditingController consumptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20, right: 20, top: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car, color: Colors.blueAccent, size: 28),
                        SizedBox(width: 8),
                        Text('Roadtrip Modu 🚙', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aracının yakıt tipini ve 100 km\'deki ortalama tüketimini gir, yakıt masrafını bütçene yansıtalım.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      value: selectedFuelType,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Yakıt Tipi',
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.local_gas_station, color: Colors.blueAccent),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'gasoline', child: Text('Benzin')),
                        DropdownMenuItem(value: 'diesel', child: Text('Motorin')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedFuelType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: consumptionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '100 km\'de Ortalama Tüketim (Litre)',
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        hintText: 'Örn: 6.5',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.speed, color: Colors.blueAccent),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final consumptionText = consumptionController.text.replaceAll(',', '.');
                          final consumption = double.tryParse(consumptionText);

                          if (consumption == null || consumption <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lütfen geçerli bir tüketim değeri girin!'), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }

                          Navigator.pop(bottomSheetContext);

                          final vehicleData = {
                            "name": selectedFuelType == 'gasoline' ? "Özel Araç (Benzin)" : "Özel Araç (Motorin)",
                            "type": selectedFuelType,
                            "consumption": consumption,
                          };

                          cubit.calculateRoadtripCost(vehicleData, _localItinerary);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Yakıt hesaplanıyor... ⛽'), backgroundColor: Colors.blueAccent),
                          );
                        },
                        child: const Text('Maliyeti Hesapla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (cubit.isRoadtripMode) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Roadtrip Modunu Kapat'),
                          onPressed: () {
                            cubit.disableRoadtripMode();
                            Navigator.pop(bottomSheetContext);
                          },
                        ),
                      )
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  void _showAddCustomSpotModal(BuildContext context, int dayIndex) {
    LatLng initialMapCenter = const LatLng(36.8969, 30.7133);

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

  Widget _buildBudgetTracker() {
    return BlocBuilder<TripOptimizerCubit, TripOptimizerState>(
      builder: (context, state) {
        final cubit = context.read<TripOptimizerCubit>();
        final mlWarning = cubit.mlBudgetWarning;
        final mlPredictedCost = cubit.mlPredictedCost;

        // YENİ: Cubit'teki ekstra masrafları (Yakıt vs.) topluyoruz
        double extraCosts = cubit.extraExpenses.fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

        // YENİ: Mekan ücretleri + Yakıt masrafı
        final spent = _totalSpent + extraCosts;
        final remaining = widget.maxBudget - spent;

        final isOverBudget = spent > widget.maxBudget;

        double progress = 0.0;
        if (widget.maxBudget > 0) {
          progress = (spent / widget.maxBudget).clamp(0.0, 1.0);
        } else {
          progress = spent > 0 ? 1.0 : 0.0;
        }

        Color progressColor;
        if (isOverBudget) {
          progressColor = Colors.redAccent;
        } else if (progress > 0.8) {
          progressColor = Colors.orangeAccent;
        } else {
          progressColor = Colors.greenAccent;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isOverBudget ? Colors.redAccent.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Maliyet Özeti',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverBudget ? Colors.redAccent.withOpacity(0.2) : progressColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOverBudget ? 'Bütçe Aşıldı!' : 'Kalan: ${remaining.toStringAsFixed(0)} ₺',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Harcanan', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${spent.toStringAsFixed(0)} ₺',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Toplam Bütçe', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.maxBudget.toStringAsFixed(0)} ₺',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              // ==========================================
              // YENİ: ROADTRIP YAKIT BİLGİ KARTI
              // ==========================================
              if (cubit.isRoadtripMode && cubit.selectedVehicle != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          cubit.selectedVehicle!['type'] == 'electric' ? Icons.electric_car : Icons.local_gas_station,
                          color: Colors.blueAccent,
                          size: 28
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${cubit.selectedVehicle!['name']}',
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tahmini Yakıt Masrafı: ${cubit.totalFuelCost.toStringAsFixed(0)} ₺',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ==========================================
              // MAKİNE ÖĞRENMESİ BÜTÇE UYARI KARTI
              // ==========================================
              if (mlWarning != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_alt, color: Colors.orangeAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yapay Zeka Bütçe Kâhini 🔮',
                              style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mlWarning,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (mlPredictedCost != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.psychology_alt, color: Colors.greenAccent, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Yapay Zeka Kâhini 🔮\nBütçe planlaması harika, bir sorun görünmüyor!',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Seyahat Rotam 🗺',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // YENİ: Canlı Ortak Düzenleme (Real-time) Butonu
          BlocBuilder<TripOptimizerCubit, TripOptimizerState>(
            builder: (context, state) {
              final cubit = context.read<TripOptimizerCubit>();
              final isLive = cubit.currentCloudItineraryId != null;

              return IconButton(
                icon: Icon(
                  isLive ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  color: isLive ? Colors.greenAccent : Colors.white54,
                  size: 26,
                ),
                tooltip: isLive ? 'Canlı Bağlantıyı Kapat' : 'Canlı Ortak Planlama',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) {
                      final codeController = TextEditingController();
                      return AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: Text(
                            isLive ? 'Canlı Bağlantı Aktif 🟢' : 'Ortak Planlama 🤝',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // EĞER ZATEN BİR ODAYA BAĞLIYSAK KODU GÖSTER
                            if (isLive) ...[
                              const Text(
                                'Arkadaşının bu rotaya katılması için aşağıdaki "Oda Kodunu" kopyalayıp ona gönder:',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.greenAccent.withOpacity(0.5))
                                ),
                                child: SelectableText(
                                  cubit.currentCloudItineraryId!,
                                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                icon: const Icon(Icons.wifi_off),
                                label: const Text('Bağlantıyı Kes'),
                                onPressed: () {
                                  cubit.stopListeningToCloud();
                                  Navigator.pop(dialogContext);
                                  cubit.emit(BudgetUpdatedState()); // Arayüzü yenile
                                },
                              )
                            ]
                            // EĞER HİÇBİR ODAYA BAĞLI DEĞİLSEK YENİ ODA KUR VEYA KATIL
                            else ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                                icon: const Icon(Icons.add),
                                label: const Text('Yeni Canlı Rota Başlat'),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  cubit.saveItinerary(_localItinerary);
                                },
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text('VEYA', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                              ),
                              TextField(
                                controller: codeController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Arkadaşının Rota Kodunu Gir',
                                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                  filled: true,
                                  fillColor: Color(0xFF0F172A),
                                  border: OutlineInputBorder(borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size.fromHeight(45)
                                ),
                                onPressed: () {
                                  if (codeController.text.isNotEmpty) {
                                    Navigator.pop(dialogContext);
                                    // YENİ: Kodu alıp o frekansı dinlemeye başlıyoruz!
                                    cubit.listenToCloudItinerary(codeController.text.trim());
                                    cubit.emit(BudgetUpdatedState());
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Arkadaşının rotasına bağlanıldı! 🟢'), backgroundColor: Colors.green),
                                    );
                                  }
                                },
                                child: const Text('Rotaya Katıl', style: TextStyle(fontWeight: FontWeight.bold)),
                              )
                            ]
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
            ),
          BlocBuilder<TripOptimizerCubit, TripOptimizerState>(
            builder: (context, state) {
              final cubit = context.read<TripOptimizerCubit>();
              return IconButton(
                icon: Icon(
                  cubit.isRoadtripMode ? Icons.directions_car : Icons.car_rental,
                  color: cubit.isRoadtripMode ? Colors.greenAccent : Colors.white70,
                  size: 26,
                ),
                tooltip: 'Araç Seçimi (Roadtrip Modu)',
                onPressed: () => _showVehicleSelectionModal(context),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.luggage_rounded, color: Colors.tealAccent, size: 24),
            tooltip: 'Akıllı Bavul Asistanı',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SmartPackingView(itinerary: _localItinerary),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'share') {
                showDialog(
                  context: context,
                  builder: (context) {
                    final titleController = TextEditingController(text: "Harika Bir Seyahat Rotası");
                    return AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      title: const Text("Rotayı Toplulukta Paylaş 🌍", style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Rota Başlığı",
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("İptal", style: TextStyle(color: Colors.grey)),
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
              } else if (value == 'pdf') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfPreviewView(itinerary: _localItinerary),
                  ),
                );
              } else if (value == 'budget') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BudgetAssistantView(itinerary: _localItinerary),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Toplulukta Paylaş', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text('PDF Oluştur / Paylaş', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'budget',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Bütçe Asistanı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildBudgetTracker(),
          Expanded(
            child: BlocListener<TripOptimizerCubit, TripOptimizerState>(
              listener: (context, state) {
                // 1. DOKUNUŞ: Kuyruğa girmiş eski bildirimleri anında temizle (Spam'i engeller)
                ScaffoldMessenger.of(context).clearSnackBars();

                if (state is ItinerarySaved) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rota Başarıyla Kaydedildi! 💾'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3), // 2. DOKUNUŞ: Tam 3 saniye ekranda kalır
                    ),
                  );
                } else if (state is TripOptimizerError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                // Buluttan Canlı Veri (Real-time) geldiğinde ekranı güncelle
                else if (state is RouteOptimized) {
                  final cubit = context.read<TripOptimizerCubit>();
                  if (cubit.currentCloudItineraryId != null) {
                    setState(() {
                      _localItinerary = List<ItineraryDayEntity>.from(state.itinerary);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rota güncellendi! 🔄'),
                        backgroundColor: Colors.blueAccent,
                        duration: Duration(seconds: 3), // 2. DOKUNUŞ: Tam 3 saniye ekranda kalır
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 120.0),
                itemCount: _localItinerary.length + 1,
                itemBuilder: (context, index) {
                  if (index == _localItinerary.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
                      child: Column(
                        children: [
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
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
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
                                          dayPlan: dayPlan,
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
                              style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
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
                              child: Padding(
                                key: ValueKey('list_tile_${spot.name}_$spotIndex'),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: spot.imagePath != null
                                          ? Image.file(
                                        File(spot.imagePath!),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                          : spot.imageUrl != null && spot.imageUrl!.isNotEmpty
                                          ? Image.network(
                                        spot.imageUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(spot.category),
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                          : Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(spot.category),
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${spotIndex + 1}. ${spot.name}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  spot.category.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                              const SizedBox(width: 2),
                                              Text(
                                                spot.rating.toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.directions, color: Colors.blueAccent, size: 24),
                                      tooltip: 'Yol Tarifi Al',
                                      onPressed: () => _launchMaps(spot.lat, spot.lng, spot.name),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: spot.entryFee > 0 ? Colors.white.withOpacity(0.05) : Colors.greenAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: spot.entryFee > 0 ? Colors.white12 : Colors.greenAccent.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        spot.entryFee > 0 ? '${spot.entryFee} ₺' : 'Ücretsiz',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: spot.entryFee > 0 ? Colors.white : Colors.greenAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
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
                              backgroundColor: Colors.blueAccent.withOpacity(0.1),
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
          ),
        ],
      ),
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
  final ItineraryDayEntity dayPlan;

  const DayWeatherBadge({
    super.key,
    required this.lat,
    required this.lng,
    required this.dayPlan,
  });

  @override
  State<DayWeatherBadge> createState() => _DayWeatherBadgeState();
}

class _DayWeatherBadgeState extends State<DayWeatherBadge> {
  WeatherModel? _weather;
  bool _isLoading = true;
  bool _alertShown = false;

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

      _checkWeatherAlerts();
    }
  }

  void _checkWeatherAlerts() {
    if (_weather == null || _alertShown) return;

    final String icon = _weather!.iconCode;
    final bool isBadWeather = icon.startsWith('09') || icon.startsWith('10') || icon.startsWith('11') || icon.startsWith('13');

    final hasOutdoorSpot = widget.dayPlan.places.any((spot) =>
    spot.category.toLowerCase() == 'nature' || spot.category.toLowerCase() == 'history');

    if (isBadWeather && hasOutdoorSpot) {
      _alertShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAlternativeRouteDialog();
      });
    }
  }

  void _showAlternativeRouteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
              SizedBox(width: 8),
              Text('Kötü Hava Uyarısı!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.dayPlan.day}. Gün rotanda yağışlı/kötü hava bekleniyor (${_weather!.temperature.round()}°C).',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 12),
              const Text(
                'Açık hava (Doğa/Tarih) mekanları yerine kapalı mekan alternatifleri (Müze/AVM) eklemek ister misin?',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Riski Alacağım', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);

                final outdoorSpots = widget.dayPlan.places.where((spot) =>
                spot.category.toLowerCase() == 'nature' ||
                    spot.category.toLowerCase() == 'history' ||
                    spot.isOutdoor
                ).toList();

                if (outdoorSpots.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Açık hava mekanı bulunamadı.'),
                        backgroundColor: Colors.grey,
                      ),
                    );
                  }
                  return;
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Yapay zeka kapalı mekan alternatifleri arıyor... 🔍'),
                      backgroundColor: Colors.orangeAccent,
                      duration: Duration(seconds: 10),
                    ),
                  );
                }

                final cubit = context.read<TripOptimizerCubit>();
                bool anySuccess = false;
                String? lastError;

                for (final spot in outdoorSpots) {
                  final errorMessage = await cubit.replaceSpotWithAIAlternatives(widget.dayPlan, spot);
                  if (errorMessage == null) {
                    anySuccess = true;
                  } else {
                    lastError = errorMessage;
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(anySuccess
                          ? 'Kapalı mekan alternatifleri eklendi! 🪄'
                          : 'Hata: ${lastError ?? "Bilinmeyen hata"}'),
                      backgroundColor: anySuccess ? Colors.deepPurpleAccent : Colors.redAccent,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                  if (anySuccess) setState(() {});
                }
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Alternatif Üret', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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

    final String icon = _weather!.iconCode;
    final bool isBadWeather = icon.startsWith('09') || icon.startsWith('10') || icon.startsWith('11') || icon.startsWith('13');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBadWeather ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBadWeather ? Colors.redAccent.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Image.network(
            'https://openweathermap.org/img/wn/$icon.png',
            width: 32,
            height: 32,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 4),
          Text(
            '${_weather!.temperature.round()}°C',
            style: TextStyle(
              color: isBadWeather ? Colors.redAccent.shade100 : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_selectedImagePath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 18),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                                    SizedBox(width: 4),
                                    Text('Harita İkonu Olarak Kullanılacak',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                            'Harita İçin Kapak Fotoğrafı Ekle',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pin yerine senin fotoğrafın görünecek 📸',
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