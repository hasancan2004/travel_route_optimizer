import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';

class TravelerStatsView extends StatefulWidget {
  const TravelerStatsView({super.key});

  @override
  State<TravelerStatsView> createState() => _TravelerStatsViewState();
}

class _TravelerStatsViewState extends State<TravelerStatsView> {
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    // Ekran açılır açılmaz en güncel rotaları (ve varsa bulut senkronizasyonunu) tetikliyoruz
    context.read<TripOptimizerCubit>().loadTravelerStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text('Gezgin İstatistikleri 📊', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<TripOptimizerCubit, TripOptimizerState>(
        builder: (context, state) {
          if (state is TripOptimizerLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (state is TravelerStatsLoaded) {
            final itineraries = state.itineraries;

            // --- DİNAMİK HESAPLAMA ALGORİTMASI ---
            int totalTrips = itineraries.length;
            double totalWalkedKm = 0.0;
            double totalSpentMoney = 0.0;
            Map<String, int> categoryCounts = {};

            for (var itinerary in itineraries) {
              for (var day in itinerary) {
                totalWalkedKm += day.estimatedWalkingKm;
                for (var spot in day.places) {
                  totalSpentMoney += spot.entryFee;
                  // Kategori frekansını sayıyoruz
                  categoryCounts[spot.category] = (categoryCounts[spot.category] ?? 0) + 1;
                }
              }
            }

            // En çok tekrar eden kategoriyi bulma
            String topCategory = "Henüz Yok";
            if (categoryCounts.isNotEmpty) {
              topCategory = categoryCounts.entries
                  .reduce((a, b) => a.value > b.value ? a : b)
                  .key;
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tekrar Hoş Geldin!',
                    style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Seyahat & Ekonomi Özetin',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Tamamlanan Rota', '$totalTrips', 'Adet', Icons.map_outlined, Colors.blueAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Yürünen Mesafe', totalWalkedKm.toStringAsFixed(1), 'km', Icons.directions_walk, Colors.greenAccent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Harcanan Tutar', totalSpentMoney.toStringAsFixed(0), '₺', Icons.account_balance_wallet_outlined, Colors.orangeAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Favori Kategori', topCategory, '', Icons.account_balance, Colors.purpleAccent)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  const Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text('Son 6 Rotadaki Harcamalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Grafik için harcamaları son 6 rotaya göre eşleştiriyoruz
                  _buildDynamicBarChart(itineraries),

                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade900.withOpacity(0.5), Colors.blue.shade800.withOpacity(0.2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sıradaki Hedefin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                totalWalkedKm > 10
                                    ? 'Harika bir kardiyo çıkardın! Bir sonraki rotanda doğa parklarını keşfederek seriyi sürdürebilirsin.'
                                    : 'Yeni yerler keşfetmek için harika bir gün. Hadi yeni bir rota oluşturalım!',
                                style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }

          return const Center(child: Text("Rotanız bulunmuyor", style: TextStyle(color: Colors.white)));
        },
      ),
    );
  }

  Widget _buildDynamicBarChart(List<dynamic> itineraries) {
    // Son 6 rotanın toplam harcamalarını alıyoruz (yoksa 0)
    List<double> recentExpenses = List.filled(6, 0.0);
    int startIndex = itineraries.length > 6 ? itineraries.length - 6 : 0;

    for (int i = startIndex; i < itineraries.length; i++) {
      double tripExpense = 0;
      for (var day in itineraries[i]) {
        for (var spot in day.places) {
          tripExpense += spot.entryFee;
        }
      }
      recentExpenses[i - startIndex] = tripExpense;
    }

    double maxExpense = recentExpenses.isNotEmpty ? recentExpenses.reduce((a, b) => a > b ? a : b) : 0;
    if (maxExpense == 0) maxExpense = 1000; // Grafik patlamasın diye varsayılan tavan

    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 24, right: 24, left: 12, bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxExpense * 1.2, // Tavanı %20 yüksek tutuyoruz ki çubuklar tepeye yapışmasın
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueAccent,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()} ₺',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('R${value.toInt() + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12))
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text('${(value / 1000).toStringAsFixed(1)}k', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxExpense > 0 ? maxExpense / 3 : 1000,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1, dashArray: [5, 5]),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(6, (index) {
            bool isMax = recentExpenses[index] == maxExpense && maxExpense > 0;
            return _buildBarGroup(index, recentExpenses[index], isMax ? Colors.orangeAccent : Colors.blueAccent);
          }),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
              ]
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: y > 0 ? y * 1.2 : 1000,
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ],
    );
  }
}