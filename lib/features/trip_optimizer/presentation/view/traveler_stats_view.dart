import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TravelerStatsView extends StatefulWidget {
  const TravelerStatsView({super.key});

  @override
  State<TravelerStatsView> createState() => _TravelerStatsViewState();
}

class _TravelerStatsViewState extends State<TravelerStatsView> {
  // Koyu Tema Renk Paleti (Premium Slate)
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);

  // NOT: Bu veriler şu an UI'ı görmek için statiktir (Mock Data).
  // Bir sonraki aşamada Hive/Isar gibi yerel veritabanını bağladığımızda,
  // bu verileri kullanıcının telefon hafızasından canlı olarak çekeceğiz.
  final int totalTrips = 12;
  final double totalWalkedKm = 145.5;
  final double totalSpentMoney = 18450.0;
  final String topCategory = "Tarih / Müze";

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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Karşılama Alanı
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

            // 4'lü İstatistik Izgarası (Grid)
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
                Expanded(child: _buildStatCard('Yönetilen Bütçe', '18.4K', '₺', Icons.account_balance_wallet_outlined, Colors.orangeAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Favori Kategori', topCategory, '', Icons.account_balance, Colors.purpleAccent)),
              ],
            ),
            const SizedBox(height: 32),

            // Finansal Analiz Grafiği (Bar Chart)
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('Son 6 Rotadaki Harcamalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
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
                  maxY: 6000,
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
                          const style = TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12);
                          String text;
                          switch (value.toInt()) {
                            case 0: text = 'Oca'; break;
                            case 1: text = 'Şub'; break;
                            case 2: text = 'Mar'; break;
                            case 3: text = 'Nis'; break;
                            case 4: text = 'May'; break;
                            case 5: text = 'Haz'; break;
                            default: text = ''; break;
                          }
                          return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: style));
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
                    horizontalInterval: 1500,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1, dashArray: [5, 5]),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBarGroup(0, 1200, Colors.blueAccent),
                    _buildBarGroup(1, 3500, Colors.blueAccent),
                    _buildBarGroup(2, 2100, Colors.blueAccent),
                    _buildBarGroup(3, 4800, Colors.blueAccent),
                    _buildBarGroup(4, 1500, Colors.blueAccent),
                    _buildBarGroup(5, 5200, Colors.orangeAccent), // En yüksek harcama vurgusu
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Gezgin Tavsiyesi Kartı
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
                          'Yürüyüş mesafen çok iyi! Bir sonraki rotanda doğa parklarını keşfederek seriyi sürdürebilirsin.',
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
      ),
    );
  }

  // İstatistik Kartı Oluşturucu Metot
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

  // Bar Chart Sütun Oluşturucu Metot
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
            toY: 6000,
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ],
    );
  }
}