import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerView extends StatefulWidget {
  final LatLng initialCenter;

  const LocationPickerView({
    super.key,
    // Not: Buradaki Antalya varsayılanı sadece "eğer hiçbir veri gelmezse" diyedir.
    // Esas çözüm, bir önceki sayfadan (trip_form_view) kullanıcının seçtiği şehrin
    // koordinatlarını bu sayfaya parametre olarak yollamaktır.
    this.initialCenter = const LatLng(36.8969, 30.7133),
  });

  @override
  State<LocationPickerView> createState() => _LocationPickerViewState();
}

class _LocationPickerViewState extends State<LocationPickerView> {
  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  bool _isLoadingLocation = false;
  bool _locationPermissionGranted = false;

  // Arama çubuğu için controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialCenter;
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    if (mounted) {
      setState(() {
        _locationPermissionGranted = true;
      });
    }
  }

  Future<void> _moveToUserLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: userLatLng, zoom: 15.0),
            ));

        setState(() {
          _selectedLocation = userLatLng;
        });
      }
    } catch (e) {
      // Hata durumu
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // Arama butonu simülasyonu (İleride burayı Google Places API'ye bağlayacağız)
  void _onSearchPlace(String query) {
    if (query.isEmpty) return;
    // Buraya Google Places HTTP isteği gelecek.
    // Şimdilik sadece klavyeyi kapatıyoruz.
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$query" aranıyor... (API bağlantısı eklenecek)'),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Koyu Tema Renk Paleti
    const Color darkBackground = Color(0xFF0F172A); // Scaffold Arka Planı
    const Color cardColor = Color(0xFF1E293B); // AppBar ve Alt Kutu Arka Planı

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: const Text('Haritadan Konum Seç', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cardColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.initialCenter,
                    zoom: 13.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  onTap: (LatLng tappedLocation) {
                    // Klavyeyi gizle
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _selectedLocation = tappedLocation;
                    });
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected_pin'),
                      position: _selectedLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(title: 'Seçilen Konum'),
                    ),
                  },
                  myLocationEnabled: _locationPermissionGranted,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                ),

                // YENİ: Arama Çubuğu (Search Bar)
                Positioned(
                  top: 16,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchPlace,
                      decoration: InputDecoration(
                        hintText: 'Mekan veya adres ara...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),

                // Konumuma Git Butonu
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'btnFindMe',
                    backgroundColor: cardColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _moveToUserLocation,
                    child: _isLoadingLocation
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // Alt Bilgi ve Onay Alanı (Koyu Tema)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -5)),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enlem: ${_selectedLocation.latitude.toStringAsFixed(4)}\nBoylam: ${_selectedLocation.longitude.toStringAsFixed(4)}',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(_selectedLocation);
                      },
                      child: const Text(
                        'Bu Konumu Onayla',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Vazgeç',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}