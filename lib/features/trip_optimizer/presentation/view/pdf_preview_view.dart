import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/itinerary_day_entity.dart';
import '../../../../core/services/notification_service.dart';

class PdfPreviewView extends StatelessWidget {
  final List<ItineraryDayEntity> itinerary;

  const PdfPreviewView({super.key, required this.itinerary});

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TRIP OPTIMIZER', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text('Seyahat Planı', style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey600)),
                ],
              ),
              pw.Divider(thickness: 2, color: PdfColors.blueAccent),
              pw.SizedBox(height: 10),
            ],
          );
        },
        build: (pw.Context context) {
          final List<pw.Widget> pdfContent = [];

          for (var dayPlan in itinerary) {
            pdfContent.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('${dayPlan.day}. GÜN ROTASI', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text('Yürüyüş: ${dayPlan.estimatedWalkingKm.toStringAsFixed(1)} km', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    if (dayPlan.places.isEmpty)
                      pw.Text('Bu gün için henüz mekan planlanmadı.', style: const pw.TextStyle(color: PdfColors.grey600, fontStyle: pw.FontStyle.italic))
                    else
                      pw.ListView.builder(
                        itemCount: dayPlan.places.length,
                        itemBuilder: (context, index) {
                          final spot = dayPlan.places[index];
                          final feeText = spot.entryFee > 0 ? '${spot.entryFee} TL' : 'Ücretsiz';
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 5),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('${index + 1}. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                pw.Expanded(
                                  child: pw.Text('${spot.name} (${spot.category.toUpperCase()})'),
                                ),
                                pw.Text(feeText, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          }

          return pdfContent;
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'TripOptimizer ile optimize edilmiştir - Sayfa ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// PDF'i kaydeder, üstten sistem bildirimi gösterir.
  /// Bildirime tıklanınca dosya otomatik açılır.
  Future<void> _downloadPdfDirectly(BuildContext context, Uint8List bytes) async {
    try {
      String path = '';

      if (Platform.isAndroid) {
        Directory? directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
        path = '${directory?.path}/TripOptimizer_Rotam_${DateTime.now().millisecondsSinceEpoch}.pdf';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/TripOptimizer_Rotam.pdf';
      }

      final file = File(path);
      await file.writeAsBytes(bytes);

      // Üstten sistem bildirimi göster - tıklanınca dosyayı açar
      await NotificationService().showPdfDownloaded(file.path);

      // Ekranda da kısa bir onay göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ PDF indirildi! Bildirime dokun ve aç.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'AÇ',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// PDF'i paylaşma menüsüne açar (WhatsApp, Mail, Drive vb.)
  Future<void> _sharePdf(BuildContext context, Uint8List bytes) async {
    try {
      // share_plus geçici dosya yolu ister
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/TripOptimizer_Rotam.pdf');
      await tempFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'application/pdf')],
          subject: 'Seyahat Planım - TripOptimizer',
          text: 'TripOptimizer ile oluşturduğum seyahat planı 🗺️',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşma hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Çıktısı', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,

        // Solda PAYLAŞ — Sağda İNDİR
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 26),
            onPressed: (context, build, pageFormat) async {
              final bytes = await build(pageFormat);
              if (!context.mounted) return;
              await _sharePdf(context, bytes);
            },
          ),
          PdfPreviewAction(
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
            onPressed: (context, build, pageFormat) async {
              final bytes = await build(pageFormat);
              if (!context.mounted) return;
              await _downloadPdfDirectly(context, bytes);
            },
          ),
        ],
      ),
    );
  }
}