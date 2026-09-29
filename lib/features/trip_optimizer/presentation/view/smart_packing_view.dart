import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/itinerary_day_entity.dart';

class PackingItem {
  final String id;
  final String title;
  final String category;
  bool isChecked;

  PackingItem({
    required this.id,
    required this.title,
    required this.category,
    required this.isChecked,
  });

  factory PackingItem.fromMap(Map<String, dynamic> map) {
    return PackingItem(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'Genel',
      isChecked: map['is_checked'] ?? false,
    );
  }
}

class SmartPackingView extends StatefulWidget {
  final List<ItineraryDayEntity> itinerary;

  const SmartPackingView({super.key, required this.itinerary});

  @override
  State<SmartPackingView> createState() => _SmartPackingViewState();
}

class _SmartPackingViewState extends State<SmartPackingView> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<PackingItem> _items = [];
  final TextEditingController _customItemController = TextEditingController();
  bool _isLoading = true;
  RealtimeChannel? _packingChannel;

  @override
  void initState() {
    super.initState();
    _initializePackingList();
  }

  @override
  void dispose() {
    _customItemController.dispose();
    if (_packingChannel != null) {
      _supabase.removeChannel(_packingChannel!);
    }
    super.dispose();
  }

  Future<void> _initializePackingList() async {
    await _fetchAndSyncSmartList();
    _setupRealtimeSubscription();
  }

  // 1. Verileri Supabase'den çek, yoksa (ilk kez giriliyorsa) akıllı listeyi otomatik ekle
  Future<void> _fetchAndSyncSmartList() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('packing_items')
          .select()
          .eq('user_id', user.id);

      List<PackingItem> fetchedItems = (response as List)
          .map((item) => PackingItem.fromMap(item))
          .toList();

      // Eğer kullanıcının henüz hiç bavul kaydı yoksa, akıllı varsayılanları ve rotaya göre olanları ekle
      if (fetchedItems.isEmpty) {
        final defaultItems = _generateDefaultItems(user.id);
        final insertResponse = await _supabase
            .from('packing_items')
            .insert(defaultItems)
            .select();

        fetchedItems = (insertResponse as List)
            .map((item) => PackingItem.fromMap(item))
            .toList();
      }

      if (mounted) {
        setState(() {
          _items = fetchedItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Bavul yüklenirken hata: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Rotaya ve standartlara göre varsayılan eşyaları hazırla
  List<Map<String, dynamic>> _generateDefaultItems(String userId) {
    final List<Map<String, dynamic>> defaults = [
      {'user_id': userId, 'title': 'Cüzdan, Kimlik ve Kartlar 💳', 'category': 'Genel', 'is_checked': false},
      {'user_id': userId, 'title': 'Şarj Aleti ve Powerbank 🔋', 'category': 'Genel', 'is_checked': false},
      {'user_id': userId, 'title': 'Kişisel İlaçlar / İlk Yardım 💊', 'category': 'Genel', 'is_checked': false},
    ];

    bool hasNature = false;
    bool hasHistory = false;
    bool hasShopping = false;
    bool hasFood = false;

    for (var day in widget.itinerary) {
      for (var spot in day.places) {
        final cat = spot.category.toLowerCase();
        if (cat.contains('nature')) hasNature = true;
        if (cat.contains('history')) hasHistory = true;
        if (cat.contains('shopping')) hasShopping = true;
        if (cat.contains('food')) hasFood = true;
      }
    }

    if (hasNature) {
      defaults.add({'user_id': userId, 'title': 'Yürüyüş / Spor Ayakkabısı 🥾', 'category': 'Doğa Rotası', 'is_checked': false});
      defaults.add({'user_id': userId, 'title': 'Matara / Su Şişesi 💧', 'category': 'Doğa Rotası', 'is_checked': false});
      defaults.add({'user_id': userId, 'title': 'Güneş Gözlüğü ve Şapka 🧢', 'category': 'Doğa Rotası', 'is_checked': false});
    }

    if (hasHistory) {
      defaults.add({'user_id': userId, 'title': 'Müze Kart 🏛️', 'category': 'Tarih Rotası', 'is_checked': false});
      defaults.add({'user_id': userId, 'title': 'Kulaklık (Rehber dinlemek için) 🎧', 'category': 'Tarih Rotası', 'is_checked': false});
    }

    if (hasShopping) {
      defaults.add({'user_id': userId, 'title': 'Bez Alışveriş Çantası 🛍️', 'category': 'Alışveriş', 'is_checked': false});
    }

    if (hasFood) {
      defaults.add({'user_id': userId, 'title': 'Mide Koruyucu / Sindirim İlacı 🍽️', 'category': 'Yemek', 'is_checked': false});
    }

    defaults.add({'user_id': userId, 'title': 'Şemsiye veya Yağmurluk ☂️', 'category': 'Hava Tedbiri', 'is_checked': false});

    return defaults;
  }

  // 2. Realtime Dinleyici: Diğer cihazdan yapılan değişiklikleri anında ekrana yansıt
  void _setupRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _packingChannel = _supabase
        .channel('public:packing_items')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'packing_items',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) {
        _fetchAndSyncSmartList();
      },
    )
        .subscribe();
  }

  // Eşya tik durumunu Supabase'de güncelle
  Future<void> _toggleItemCheck(PackingItem item, bool newValue) async {
    setState(() {
      item.isChecked = newValue;
    });

    try {
      await _supabase
          .from('packing_items')
          .update({'is_checked': newValue})
          .eq('id', item.id);
    } catch (e) {
      print("Tik güncellenirken hata: $e");
    }
  }

  // Yeni özel eşya ekle ve Supabase'e kaydet
  Future<void> _addNewItem() async {
    final text = _customItemController.text.trim();
    final user = _supabase.auth.currentUser;
    if (text.isEmpty || user == null) return;

    FocusScope.of(context).unfocus();
    _customItemController.clear();

    try {
      final response = await _supabase
          .from('packing_items')
          .insert({
        'user_id': user.id,
        'title': text,
        'category': 'Özel Eklenen',
        'is_checked': false,
      })
          .select()
          .single();

      final newItem = PackingItem.fromMap(response);
      setState(() {
        _items.insert(0, newItem);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eşya buluta eklendi! 🎒☁️'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Özel eşya eklenirken hata: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _items.where((i) => i.isChecked).length;
    final progress = _items.isNotEmpty ? completedCount / _items.length : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Akıllı Bavul Asistanı 🧳', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Column(
        children: [
          // İlerleme Kartı
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hazırlık Durumu', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$completedCount / ${_items.length} Tamamlandı ☁️', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                  ),
                ),
              ],
            ),
          ),

          // Eşya Ekleme Alanı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customItemController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addNewItem(),
                    decoration: InputDecoration(
                      hintText: 'Listeye özel eşya ekle...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _addNewItem,
                  child: const Icon(Icons.add, size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Liste
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: item.isChecked ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.w600,
                        decoration: item.isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(
                      item.category,
                      style: TextStyle(color: Colors.tealAccent.shade100, fontSize: 11),
                    ),
                    value: item.isChecked,
                    activeColor: Colors.tealAccent,
                    checkColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onChanged: (val) {
                      if (val != null) {
                        _toggleItemCheck(item, val);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}