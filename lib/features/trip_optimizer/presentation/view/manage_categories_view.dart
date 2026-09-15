import 'package:flutter/material.dart';

class ManageCategoriesView extends StatefulWidget {
  final List<Map<String, String>> currentCategories;

  const ManageCategoriesView({super.key, required this.currentCategories});

  @override
  State<ManageCategoriesView> createState() => _ManageCategoriesViewState();
}

class _ManageCategoriesViewState extends State<ManageCategoriesView> {
  late List<Map<String, String>> _localCategories;

  // Premium Dark Theme Renkleri
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    // Gelen listeyi kopyalıyoruz ki anında değişiklik yapabilelim
    _localCategories = List<Map<String, String>>.from(
      widget.currentCategories.map((e) => Map<String, String>.from(e)),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg, // Dialog arka planı koyu
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Yeni Kategori Ekle', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white), // Yazılan yazı beyaz
            decoration: InputDecoration(
              hintText: 'Örn: Okul 🎓',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: darkBg, // TextField içi daha da koyu
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  // Backend için boşlukları silip küçük harfe çevirerek unique bir value oluşturuyoruz
                  final value = text.toLowerCase().replaceAll(' ', '_');
                  setState(() {
                    _localCategories.add({'label': text, 'value': value});
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope kullanarak geri tuşuna basıldığında güncel listeyi yolluyoruz
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _localCategories);
      },
      child: Scaffold(
        backgroundColor: darkBg, // Tüm sayfanın arka planı
        appBar: AppBar(
          title: const Text('Kategorileri Yönet', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent, // AppBar şeffaf, arka planla bütünleşik
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _localCategories),
          ),
        ),
        body: _localCategories.isEmpty
            ? const Center(
          child: Text(
            'Hiç kategori kalmadı.\nAlttaki butondan yeni ekleyin!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _localCategories.length,
          itemBuilder: (context, index) {
            final cat = _localCategories[index];
            return Card(
              color: cardBg, // Kartlar koyu lacivert
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.3),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white10), // Çok hafif beyazımsı kenarlık
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text(
                  cat['label']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _localCategories.removeAt(index);
                    });
                  },
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddCategoryDialog,
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add),
          label: const Text('Kategori Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}