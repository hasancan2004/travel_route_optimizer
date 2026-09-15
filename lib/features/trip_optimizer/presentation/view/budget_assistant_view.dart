import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/itinerary_day_entity.dart';
import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';


class BudgetAssistantView extends StatefulWidget {
  final List<ItineraryDayEntity> itinerary;

  const BudgetAssistantView({super.key, required this.itinerary});

  @override
  State<BudgetAssistantView> createState() => _BudgetAssistantViewState();
}

class _BudgetAssistantViewState extends State<BudgetAssistantView> {
  // Koyu Tema Renk Paleti
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);
  final Color inputBg = const Color(0xFF0F172A);

  // Kategori Renkleri
  final Map<String, Color> categoryColors = {
    'history': Colors.orangeAccent,
    'nature': Colors.greenAccent,
    'shopping': Colors.purpleAccent,
    'food': Colors.amberAccent,
    'custom': Colors.cyanAccent,
    'extra': Colors.redAccent,
  };

  void _showAddExpenseModal(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) { // İsim karışıklığını önlemek için modalContext dedik
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ekstra Harcama Ekle 💸',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Neye Harcadın? (Örn: Taksi, Su)',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.receipt_long, color: Colors.blueAccent),
                  filled: true,
                  fillColor: inputBg,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tutar (TL)',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.greenAccent),
                  filled: true,
                  fillColor: inputBg,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (titleController.text.trim().isEmpty || amountController.text.isEmpty) return;

                  // Harcamayı doğrudan Cubit'e kaydediyoruz
                  context.read<TripOptimizerCubit>().addExtraExpense(
                    titleController.text.trim(),
                    double.tryParse(amountController.text) ?? 0.0,
                  );
                  Navigator.pop(modalContext);
                },
                child: const Text('Harcamayı Ekle', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditBudgetDialog(BuildContext context) {
    final cubit = context.read<TripOptimizerCubit>();
    final budgetController = TextEditingController(text: cubit.currentTotalBudget.toInt().toString());

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Bütçeni Güncelle', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          content: TextField(
            controller: budgetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Yeni Toplam Bütçe (TL)',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
              filled: true,
              fillColor: inputBg,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('İptal', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                final newBudget = double.tryParse(budgetController.text) ?? cubit.currentTotalBudget;
                cubit.updateBudget(newBudget); // Bütçeyi Cubit üzerinden güncelliyoruz
                Navigator.pop(dialogContext);
              },
              child: const Text('Güncelle', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Kategorileri hesaplarken artık parametre olarak Cubit'ten gelen ekstra harcamaları alıyor
  Map<String, double> _calculateCategoryExpenses(List<Map<String, dynamic>> extraExpensesList) {
    Map<String, double> breakdown = {
      'history': 0.0,
      'nature': 0.0,
      'shopping': 0.0,
      'food': 0.0,
      'custom': 0.0,
      'extra': 0.0,
    };

    for (var day in widget.itinerary) {
      for (var spot in day.places) {
        String cat = spot.category.toLowerCase();
        if (breakdown.containsKey(cat)) {
          breakdown[cat] = breakdown[cat]! + spot.entryFee;
        } else {
          breakdown['custom'] = breakdown['custom']! + spot.entryFee;
        }
      }
    }

    for (var expense in extraExpensesList) {
      breakdown['extra'] = breakdown['extra']! + expense['amount'];
    }

    return breakdown;
  }

  @override
  Widget build(BuildContext context) {
    // Sayfayı BlocBuilder ile sarıyoruz ki Cubit her değiştiğinde UI anında güncellensin
    return BlocBuilder<TripOptimizerCubit, TripOptimizerState>(
      builder: (context, state) {
        final cubit = context.read<TripOptimizerCubit>();
        final totalBudget = cubit.currentTotalBudget;
        final extraList = cubit.extraExpenses;

        final Map<String, double> categoryBreakdown = _calculateCategoryExpenses(extraList);

        double totalSpent = categoryBreakdown.values.fold(0, (sum, amount) => sum + amount);
        double remainingBudget = totalBudget - totalSpent;
        double progress = (totalBudget > 0) ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
        bool isOverBudget = remainingBudget < 0;

        // Profesyonel Günlük Limit Analizi
        int totalDays = widget.itinerary.isNotEmpty ? widget.itinerary.length : 1;
        double safeDailyLimit = remainingBudget > 0 ? (remainingBudget / totalDays) : 0.0;

        return Scaffold(
          backgroundColor: darkBg,
          appBar: AppBar(
            title: const Text('Bütçe Asistanı 💰', style: TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_square, color: Colors.blueAccent),
                tooltip: 'Bütçeyi Düzenle',
                onPressed: () => _showEditBudgetDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // YENİ: Günlük Güvenli Harcama Uyarı Kartı
                if (!isOverBudget)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Colors.amberAccent, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Günlük Güvenli Limit', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text(
                                '${safeDailyLimit.toStringAsFixed(0)} ₺ / gün',
                                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // 1. ANA GRAFİK KARTI (Donut Chart)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kalan Bütçen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOverBudget ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOverBudget ? 'AŞILDI' : 'GÜVENLİ',
                              style: TextStyle(color: isOverBudget ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 30),

                      SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 4,
                                centerSpaceRadius: 65,
                                startDegreeOffset: 270,
                                sections: totalSpent == 0
                                    ? [
                                  PieChartSectionData(
                                    color: Colors.blueGrey.shade800,
                                    value: 1,
                                    title: '',
                                    radius: 20,
                                  )
                                ]
                                    : categoryBreakdown.entries
                                    .where((entry) => entry.value > 0)
                                    .map((entry) {
                                  return PieChartSectionData(
                                    color: categoryColors[entry.key],
                                    value: entry.value,
                                    title: '',
                                    radius: 25,
                                  );
                                }).toList(),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${remainingBudget.toStringAsFixed(0)} ₺',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: isOverBudget ? Colors.redAccent : Colors.white
                                    ),
                                  ),
                                  Text(
                                    'Kalan',
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: inputBg,
                          valueColor: AlwaysStoppedAnimation<Color>(isOverBudget ? Colors.redAccent : Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryItem('Toplam Bütçe', '${totalBudget.toStringAsFixed(0)} ₺', Icons.account_balance_wallet, Colors.blueAccent),
                          _buildSummaryItem('Harcanan', '${totalSpent.toStringAsFixed(0)} ₺', Icons.shopping_bag_outlined, Colors.orangeAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Harcama Dağılımı (Kategori İkonları)
                if (totalSpent > 0) ...[
                  const Text('Harcama Dağılımı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: categoryBreakdown.entries.where((e) => e.value > 0).map((entry) {
                      return Container(
                        width: (MediaQuery.of(context).size.width - 52) / 2,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: categoryColors[entry.key]!.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: categoryColors[entry.key], shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_getCategoryName(entry.key), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                  Text('${entry.value} ₺', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // EKSTRA HARCAMALAR LİSTESİ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ekstra Harcamalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    TextButton.icon(
                      onPressed: () => _showAddExpenseModal(context),
                      icon: const Icon(Icons.add, color: Colors.blueAccent),
                      label: const Text('Ekle', style: TextStyle(color: Colors.blueAccent)),
                      style: TextButton.styleFrom(backgroundColor: Colors.blueAccent.withOpacity(0.1)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                if (extraList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: const Center(child: Text('Henüz ekstra bir harcama eklemedin.', style: TextStyle(color: Colors.white54))),
                  )
                else
                  Container(
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: extraList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final expense = extraList[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.receipt, color: Colors.redAccent),
                          ),
                          title: Text(expense['title'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          trailing: Text('${expense['amount']} ₺', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.redAccent)),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String title, String amount, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }

  String _getCategoryName(String key) {
    switch(key) {
      case 'history': return 'Tarih / Müze';
      case 'nature': return 'Doğa / Park';
      case 'shopping': return 'Alışveriş';
      case 'food': return 'Yemek';
      case 'extra': return 'Ekstra Gider';
      default: return 'Diğer';
    }
  }
}