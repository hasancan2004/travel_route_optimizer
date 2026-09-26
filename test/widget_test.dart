import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_route_optimizer/main.dart';

void main() {
  testWidgets('Uygulama basariyla basliyor mu testi', (WidgetTester tester) async {
    // Uygulamamızı (artık TripOptimizerApp) başlatıyoruz.
    await tester.pumpWidget(const TripOptimizerApp());

    // Uygulama ilk açıldığında ekranda splash (yükleme) ekranının 
    // geldiğini (siyah ekranda kalmadığını) doğruluyoruz.
    expect(find.text('Yolculuk Hazırlanıyor...'), findsOneWidget);
  });
}