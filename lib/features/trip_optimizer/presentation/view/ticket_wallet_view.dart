import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'ticket_scanner_view.dart'; // YENİ: Tarayıcı sayfamızı import ettik

class TicketWalletView extends StatefulWidget {
  const TicketWalletView({super.key});

  @override
  State<TicketWalletView> createState() => _TicketWalletViewState();
}

class _TicketWalletViewState extends State<TicketWalletView> {
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);

  // Listemizi dinamik hale getirdik. İleride Hive veya Isar ile lokale kaydedeceğiz.
  final List<Map<String, dynamic>> myTickets = [
    {
      'title': 'Louvre Müzesi Giriş',
      'date': '12 Ekim 2026',
      'data': 'TICKET_LOUVRE_8475639',
      'type': 'Müze',
      'color': Colors.orangeAccent,
    },
    {
      'title': 'THY İstanbul - Paris',
      'date': '10 Ekim 2026',
      'data': 'PNR_TK1823_ISTCDG',
      'type': 'Uçuş',
      'color': Colors.blueAccent,
    }
  ];

  void _showQRDialog(String title, String data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // İŞTE SİHİR BURADA: Veriyi anında QR koda çeviren widget
                QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: Colors.black,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text('Bilet & Evrak Cüzdanı', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.greenAccent),
            tooltip: 'Karekod Okut & Ekle',
            onPressed: () async {
              // YENİ: Tarayıcıya gidiyoruz ve okunan veriyi bekliyoruz
              final scannedData = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (context) => const TicketScannerView()),
              );

              // Eğer kullanıcı kamerayı geri tuşuyla kapatmadıysa ve veri geldiyse:
              if (scannedData != null && scannedData.isNotEmpty) {
                setState(() {
                  // Okunan veriyi yeni bir bilet olarak listeye ekliyoruz
                  myTickets.add({
                    'title': 'Yeni Okunan Bilet 🎫',
                    'date': 'Bugün', // Şimdilik sabit, ileride DateTime.now() ile dinamik yapılabilir
                    'data': scannedData,
                    'type': 'Genel',
                    'color': Colors.greenAccent,
                  });
                });

                // Başarı mesajı
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bilet başarıyla cüzdana eklendi! 🎉'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: myTickets.isEmpty
          ? const Center(
        child: Text(
          'Henüz bir bilet eklemedin.\nSağ üstten QR okutarak başla!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: myTickets.length,
        itemBuilder: (context, index) {
          // Listeyi tersine çeviriyoruz ki yeni eklenenler en üstte çıksın
          final ticket = myTickets[myTickets.length - 1 - index];
          return GestureDetector(
            onTap: () => _showQRDialog(ticket['title'], ticket['data']),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ticket['color'].withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ticket['color'].withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.confirmation_number_outlined, color: ticket['color']),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket['title'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(ticket['date'], style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code, color: Colors.white54, size: 28),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}