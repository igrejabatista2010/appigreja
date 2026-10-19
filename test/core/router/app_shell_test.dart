import 'package:church_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAppAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('celular (< 600): NavigationBar embaixo, sem NavigationRail', (
    tester,
  ) async {
    await _pumpAppAt(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('tablet (>= 600): NavigationRail, sem NavigationBar', (
    tester,
  ) async {
    await _pumpAppAt(tester, const Size(900, 700));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('os 5 destinos existem e abrem a página correspondente', (
    tester,
  ) async {
    await _pumpAppAt(tester, const Size(400, 800));

    for (final label in ['Início', 'Agenda', 'Comunicados', 'Oração', 'Mais']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(label)),
        findsOneWidget,
        reason: 'AppBar de "$label"',
      );
    }
  });

  testWidgets('abre em Início e mostra o texto "Em breve"', (tester) async {
    await _pumpAppAt(tester, const Size(400, 800));

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Início')),
      findsOneWidget,
    );
    expect(find.text('Em breve'), findsOneWidget);
  });
}
