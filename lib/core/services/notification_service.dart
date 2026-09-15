import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Bildirime tıklandığında açılacak dosya yolu
  static String? _pendingFilePath;

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 13+ için bildirim izni iste
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Bildirime tıklandığında tetiklenir - dosyayı açar
  static void _onNotificationTapped(NotificationResponse response) {
    final filePath = response.payload ?? _pendingFilePath;
    if (filePath != null && filePath.isNotEmpty) {
      OpenFilex.open(filePath);
    }
  }

  /// PDF indirilince sistem bildirim çubuğundan bildirim gösterir
  Future<void> showPdfDownloaded(String filePath) async {
    _pendingFilePath = filePath;

    const androidDetails = AndroidNotificationDetails(
      'pdf_download_channel',
      'PDF İndirme',
      channelDescription: 'İndirilen PDF dosyaları için bildirimler',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        'Dosyayı açmak için buraya dokunun.',
        contentTitle: '✅ PDF İndirilenlere kaydedildi!',
        summaryText: 'TripOptimizer',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0, // Bildirim ID (aynı ID varsa üzerine yazar)
      '✅ PDF İndirildi!',
      'TripOptimizer_Rotam.pdf — Açmak için dokunun',
      details,
      payload: filePath, // Tıklanınca bu yolu kullanır
    );
  }
}
