import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TicketScannerView extends StatefulWidget {
  const TicketScannerView({super.key});

  @override
  State<TicketScannerView> createState() => _TicketScannerViewState();
}

class _TicketScannerViewState extends State<TicketScannerView> {
  // Kameranın sadece bir kez okuma yapması için kontrol bayrağı
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Bilet veya QR Okut', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Kamera Katmanı
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (!_isScanned && barcode.rawValue != null) {
                  _isScanned = true;
                  final String code = barcode.rawValue!;

                  // Okunan veriyi bir önceki sayfaya (Cüzdana) geri gönderiyoruz
                  Navigator.pop(context, code);
                  break;
                }
              }
            },
          ),

          // 2. Tarayıcı Çerçevesi (UI Görselliği)
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.greenAccent,
                borderRadius: 20,
                borderLength: 40,
                borderWidth: 8,
                cutOutSize: 250,
              ),
            ),
          ),

          // 3. Alt Bilgi Metni
          const Positioned(
            bottom: 60,
            child: Text(
              'Kamerayı QR veya Barkoda hizalayın',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }
}

// Görsel Çerçeve için Yardımcı Sınıf (Kameranın ortasındaki o şık kesik çizgi efekti)
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = 150,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path();
    path.addRect(rect);
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: rect.center, width: cutOutSize, height: cutOutSize),
      Radius.circular(borderRadius),
    ));
    return path..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawPath(getOuterPath(rect), paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxRect = Rect.fromCenter(center: rect.center, width: cutOutSize, height: cutOutSize);
    final path = Path()
      ..moveTo(boxRect.left, boxRect.top + borderLength)
      ..lineTo(boxRect.left, boxRect.top)
      ..lineTo(boxRect.left + borderLength, boxRect.top)
      ..moveTo(boxRect.right - borderLength, boxRect.top)
      ..lineTo(boxRect.right, boxRect.top)
      ..lineTo(boxRect.right, boxRect.top + borderLength)
      ..moveTo(boxRect.right, boxRect.bottom - borderLength)
      ..lineTo(boxRect.right, boxRect.bottom)
      ..lineTo(boxRect.right - borderLength, boxRect.bottom)
      ..moveTo(boxRect.left + borderLength, boxRect.bottom)
      ..lineTo(boxRect.left, boxRect.bottom)
      ..lineTo(boxRect.left, boxRect.bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
