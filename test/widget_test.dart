import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplestore/main.dart';

void main() {
  testWidgets('muestra la pantalla inicial de SimpleStore', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SimpleStoreApp());

    expect(find.text('SimpleStore'), findsOneWidget);
    expect(
      find.text('Encontrá la mejor opción con búsqueda inteligente'),
      findsOneWidget,
    );
    expect(find.text('¿Qué querés encontrar?'), findsOneWidget);
  });

  testWidgets('se adapta a una pantalla móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SimpleStoreApp());

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('¿Qué querés encontrar?'), findsOneWidget);
  });
}
