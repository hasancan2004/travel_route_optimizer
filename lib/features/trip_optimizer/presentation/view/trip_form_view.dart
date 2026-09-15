import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:travel_route_optimizer/features/auth/presentation/view/login_view.dart';
import 'package:travel_route_optimizer/features/auth/presentation/viewmodel/auth_cubit.dart';
import 'package:travel_route_optimizer/features/trip_optimizer/presentation/view/saved_itineraries_view.dart';
import 'package:travel_route_optimizer/features/trip_optimizer/presentation/view/ticket_wallet_view.dart';
import 'package:travel_route_optimizer/features/trip_optimizer/presentation/view/traveler_stats_view.dart';

import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';
import 'explore_screen.dart';
import 'itinerary_view.dart';
import 'manage_categories_view.dart';

class TripFormView extends StatefulWidget {
  const TripFormView({super.key});

  @override
  State<TripFormView> createState() => _TripFormViewState();
}

class _TripFormViewState extends State<TripFormView> {
  final TextEditingController _cityController = TextEditingController(text: 'istanbul');
  final TextEditingController _budgetController = TextEditingController(text: '1000');
  final TextEditingController _daysController = TextEditingController(text: '3');

  List<Map<String, String>> _availableInterests = [
    {'label': 'Tarih 🏛️', 'value': 'history'},
    {'label': 'Doğa 🌲', 'value': 'nature'},
    {'label': 'Alışveriş 🛍️', 'value': 'shopping'},
    {'label': 'Yemek 🍔', 'value': 'food'},
  ];

  final List<String> _selectedInterests = ['history'];
  double _maxWalkPerDay = 5.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Rotanı Oluştur 🗺️', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // YENİ: İkon kalabalığını önlemek için PopupMenuButton (Üç Nokta Menüsü) eklendi
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: "Seçenekler",
            color: const Color(0xFF1E1E2C), // Tema uyumlu koyu arka plan
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'explore') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExploreScreen()),
                );
              } else if (value == 'wallet') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TicketWalletView()),
                );
              } else if (value == 'stats') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TravelerStatsView()),
                );
              } else if (value == 'saved') {
                context.read<TripOptimizerCubit>().getSavedItineraries();
              } else if (value == 'logout') {
                context.read<AuthCubit>().signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginView()),
                      (route) => false,
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'explore',
                child: Row(
                  children: [
                    Icon(Icons.explore, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Topluluk Keşfet', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'wallet',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Bilet & Cüzdan', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 12),
                    Text('İstatistikler', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'saved',
                child: Row(
                  children: [
                    Icon(Icons.folder_special, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Kayıtlı Rotalarım', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<TripOptimizerCubit, TripOptimizerState>(
        listener: (context, state) {
          if (state is TripOptimizerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }

          if (state is CitySpotsLoaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mekanlar çekildi! Rota optimize ediliyor...'), backgroundColor: Colors.blue),
            );

            context.read<TripOptimizerCubit>().optimizeRoute(
              userInterests: _selectedInterests.isEmpty ? ['history'] : _selectedInterests,
              maxBudget: double.tryParse(_budgetController.text) ?? 1000.0,
              totalDays: int.tryParse(_daysController.text) ?? 3,
              maxWalkPerDay: _maxWalkPerDay,
              places: state.spots,
            );
          }

          if (state is RouteOptimized) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rota Başarıyla Oluşturuldu! 🎉'), backgroundColor: Colors.green),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItineraryView(
                  itinerary: state.itinerary,
                  availableCategories: _availableInterests,
                ),
              ),
            );
          }

          if (state is SavedItinerariesLoaded) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedItinerariesView(savedItineraries: state.savedItineraries),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TripOptimizerLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'Hangi Şehre Gidiyorsun?',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_city),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maksimum Bütçe (TL)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Kaç Gün Kalacaksın?',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Nelerden Hoşlanırsın?',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final updatedCategories = await Navigator.push<List<Map<String, String>>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ManageCategoriesView(currentCategories: _availableInterests),
                                  ),
                                );

                                if (updatedCategories != null) {
                                  setState(() {
                                    _availableInterests = updatedCategories;
                                    _selectedInterests.removeWhere((selectedVal) =>
                                    !updatedCategories.any((cat) => cat['value'] == selectedVal));
                                  });
                                }
                              },
                              icon: const Icon(Icons.settings_outlined, size: 18),
                              label: const Text('Düzenle'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        _availableInterests.isEmpty
                            ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Hiç kategori yok. Lütfen "Düzenle" butonundan ekleyin.',
                              style: TextStyle(color: Colors.redAccent, fontStyle: FontStyle.italic)),
                        )
                            : Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _availableInterests.map((interest) {
                            final isSelected = _selectedInterests.contains(interest['value']);
                            return ChoiceChip(
                              label: Text(interest['label']!),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedInterests.add(interest['value']!);
                                  } else {
                                    _selectedInterests.remove(interest['value']);
                                  }
                                });
                              },
                              selectedColor: Colors.blueAccent.withOpacity(0.3),
                              checkmarkColor: Colors.blueAccent,
                              backgroundColor: Colors.white10,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? Colors.blueAccent : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Günlük Yürüme Limitim',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            Text(
                              '${_maxWalkPerDay.toInt()} km',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                          ],
                        ),
                        Slider(
                          value: _maxWalkPerDay,
                          min: 1.0,
                          max: 20.0,
                          divisions: 19,
                          activeColor: Colors.blueAccent,
                          inactiveColor: Colors.blueAccent.withOpacity(0.2),
                          label: '${_maxWalkPerDay.toInt()} km',
                          onChanged: (double newValue) {
                            setState(() {
                              _maxWalkPerDay = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    onPressed: () {
                      context.read<TripOptimizerCubit>().fetchCitySpots(_cityController.text);
                    },
                    child: const Text('Rotamı Optimize Et 🚀', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}