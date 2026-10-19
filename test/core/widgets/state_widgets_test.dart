import 'package:church_app/core/error/failures.dart';
import 'package:church_app/core/widgets/app_empty_view.dart';
import 'package:church_app/core/widgets/app_error_view.dart';
import 'package:church_app/core/widgets/app_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('AppLoading mostra o indicador', (tester) async {
    await tester.pumpWidget(testApp(const AppLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppEmptyView usa o texto padrão ou o informado', (tester) async {
    await tester.pumpWidget(testApp(const AppEmptyView()));
    expect(find.text('Nada por aqui ainda.'), findsOneWidget);

    await tester.pumpWidget(
      testApp(const AppEmptyView(message: 'Sem eventos')),
    );
    expect(find.text('Sem eventos'), findsOneWidget);
  });

  testWidgets('AppErrorView mostra o erro e chama onRetry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      testApp(
        AppErrorView(failure: const NetworkFailure(), onRetry: () => retried++),
      ),
    );

    expect(
      find.text('Sem conexão. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tentar novamente'));
    expect(retried, 1);
  });

  testWidgets('AppErrorView prefere a mensagem do servidor', (tester) async {
    await tester.pumpWidget(
      testApp(
        AppErrorView(
          failure: const ValidationFailure(message: 'Texto do banco.'),
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('Texto do banco.'), findsOneWidget);
  });
}
