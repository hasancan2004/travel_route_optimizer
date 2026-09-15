import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:dio/dio.dart'; // YENİ: Radar API isteği için eklendi

import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../../data/datasources/trip_remote_data_source.dart'; // YENİ: Veri kaynağımız

class DayMapView extends StatefulWidget {
  final ItineraryDayEntity dayPlan;

  const DayMapView({super.key, required this.dayPlan});

  @override
  State<DayMapView> createState() => _DayMapViewState();
}

class _DayMapViewState extends State<DayMapView> {
  // YENİ: Radar değişkenleri
  final Set<Circle> _circles = {};
  bool _isRadarScanning = false;

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _locationPermissionGranted = false;

  LatLng? _selectedTapLocation;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _initializeMapData();
  }

  Future<void> _initializeMapData() async {
    _setMarkers();
    await _getPolylines();
  }

  void _setMarkers() {
    _markers.clear();
    for (int i = 0; i < widget.dayPlan.places.length; i++) {
      final spot = widget.dayPlan.places[i];
      _markers.add(
        Marker(
          markerId: MarkerId('spot_${spot.name}_$i'),
          position: LatLng(spot.lat, spot.lng),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${spot.name}',
            snippet: spot.category.toUpperCase(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getCategoryColor(spot.category)),
          onTap: () => _showSpotDetails(context, spot, i + 1),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _getPolylines() async {
    if (widget.dayPlan.places.length < 2) return;

    String googleApiKey = "AIzaSyB96JVnwGxaCLx8CrZQcx3TNwhb2N-ozrc";
    PolylinePoints polylinePoints = PolylinePoints(apiKey: googleApiKey);

    List<LatLng> polylineCoordinates = [];

    for (int i = 0; i < widget.dayPlan.places.length - 1; i++) {
      final start = widget.dayPlan.places[i];
      final end = widget.dayPlan.places[i + 1];

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(start.lat, start.lng),
          destination: PointLatLng(end.lat, end.lng),
          mode: TravelMode.walking,
        ),
      );

      if (result.points.isNotEmpty) {
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      }
    }

    if (polylineCoordinates.isNotEmpty) {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('real_route_line'),
            points: polylineCoordinates,
            color: Colors.blueAccent,
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      });
    }
  }

  double _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'history':
        return BitmapDescriptor.hueOrange;
      case 'shopping':
        return BitmapDescriptor.hueMagenta;
      case 'nature':
        return BitmapDescriptor.hueGreen;
      case 'food':
        return BitmapDescriptor.hueYellow;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    setState(() {
      _locationPermissionGranted = true;
    });

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void _moveToCurrentLocation() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 15.0),
        ),
      );
    } else {
      _checkLocationPermission();
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> _openMapNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harita uygulaması açılamadı!')),
        );
      }
    }
  }

  // YENİ: Radar Motoru
  Future<void> _runLiveRadar() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radar için konumunuz bulunamıyor!')),
      );
      return;
    }

    setState(() {
      _isRadarScanning = true;
      _circles.add(
        Circle(
          circleId: const CircleId('radar_pulse'),
          center: _currentLocation!,
          radius: 1500, // 1.5 KM Yarıçap
          fillColor: Colors.tealAccent.withOpacity(0.2),
          strokeColor: Colors.tealAccent,
          strokeWidth: 2,
        ),
      );
    });

    try {
      final dataSource = TripRemoteDataSourceImpl(dio: Dio());
      final radarSpots = await dataSource.getRadarSpots(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          radius: 1500
      );

      setState(() {
        for (int i = 0; i < radarSpots.length; i++) {
          final spot = radarSpots[i];
          _markers.add(
            Marker(
              markerId: MarkerId('radar_spot_$i'),
              position: LatLng(spot.lat, spot.lng),
              infoWindow: InfoWindow(title: '⚡ ${spot.name}', snippet: 'RADAR KEŞFİ'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            ),
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Radar ${radarSpots.length} yeni mekan buldu! 🎯'), backgroundColor: Colors.teal),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Radar hatası: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isRadarScanning = false;
      });
    }
  }

  void _showAddSpotFromMapModal(LatLng tappedLatLng) {
    final nameController = TextEditingController();
    final feeController = TextEditingController();
    String selectedCategory = 'history';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Seçilen Konuma Mekan Ekle 📍',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Mekan Adı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'history', child: Text('Tarih 🏛️')),
                      DropdownMenuItem(value: 'nature', child: Text('Doğa 🌲')),
                      DropdownMenuItem(value: 'shopping', child: Text('Alışveriş 🛍️')),
                      DropdownMenuItem(value: 'food', child: Text('Yemek 🍔')),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tahmini Ücret (TL)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lütfen mekan adını girin.')),
                        );
                        return;
                      }

                      final newSpot = SpotEntity(
                        name: nameController.text.trim(),
                        category: selectedCategory,
                        rating: 5.0,
                        entryFee: double.tryParse(feeController.text) ?? 0.0,
                        lat: tappedLatLng.latitude,
                        lng: tappedLatLng.longitude,
                      );

                      setState(() {
                        widget.dayPlan.places.add(newSpot);
                        _selectedTapLocation = null;
                        _initializeMapData();
                      });

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Haritadan yeni mekan rotaya eklendi! ✨'),
                          backgroundColor: Colors.blueAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text(
                      'Rotaya Ekle',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerLatLng = widget.dayPlan.places.isNotEmpty
        ? LatLng(widget.dayPlan.places.first.lat, widget.dayPlan.places.first.lng)
        : const LatLng(36.8969, 30.7133);

    Set<Marker> currentMarkers = Set.from(_markers);

    if (_selectedTapLocation != null) {
      currentMarkers.add(
        Marker(
          markerId: const MarkerId('tapped_location'),
          position: _selectedTapLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Seçilen Konum'),
        ),
      );
    }

    Set<Polyline> currentPolylines = _polylines.isNotEmpty
        ? _polylines
        : {
      if (widget.dayPlan.places.length > 1)
        Polyline(
          polylineId: const PolylineId('fallback_route_line'),
          points: widget.dayPlan.places.map((s) => LatLng(s.lat, s.lng)).toList(),
          color: Colors.blueAccent.withOpacity(0.5),
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        )
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dayPlan.day}. Gün Rotası 📍'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: centerLatLng,
                    zoom: 14.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  onTap: (LatLng tappedLatLng) {
                    setState(() {
                      _selectedTapLocation = tappedLatLng;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Konum seçildi! Alttaki butondan ekleyebilirsin'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  markers: currentMarkers,
                  polylines: currentPolylines,
                  circles: _circles, // YENİ: Radar çemberi haritaya bağlandı
                  myLocationEnabled: _locationPermissionGranted,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // YENİ: Radar Butonu
                      FloatingActionButton(
                        heroTag: 'btnRadar',
                        backgroundColor: Colors.tealAccent.shade700,
                        foregroundColor: Colors.white,
                        onPressed: _isRadarScanning ? null : _runLiveRadar,
                        child: _isRadarScanning
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Icon(Icons.radar),
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        heroTag: 'btnLocation',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        onPressed: _moveToCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, color: Color(0xFF1E293B)),
                              onPressed: _zoomIn,
                            ),
                            Container(height: 1, width: 30, color: Colors.grey.shade300),
                            IconButton(
                              icon: const Icon(Icons.remove, color: Color(0xFF1E293B)),
                              onPressed: _zoomOut,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedTapLocation != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () => _showAddSpotFromMapModal(_selectedTapLocation!),
                    child: const Text(
                      'Bu Konuma Mekan Ekle',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSpotDetails(BuildContext context, SpotEntity spot, int stepNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$stepNumber. ${spot.name}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
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
                        fontSize: 14,
                        color: spot.entryFee > 0 ? Colors.black87 : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(_getCategoryIcon(spot.category), color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    spot.category.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    spot.rating.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _openMapNavigation(spot.lat, spot.lng);
                },
                icon: const Icon(Icons.directions, color: Colors.white),
                label: const Text('Yol Tarifi Al / Haritada Aç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
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