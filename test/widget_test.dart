import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/app/app.dart';
import 'package:vita_patient/app/config/app_config.dart';
import 'package:vita_patient/app/providers.dart';

void main() {
  testWidgets('unconfigured app is Arabic RTL and does not fake a login', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(
            const AppConfig(gateway: '', environment: Environment.development),
          ),
        ],
        child: const VitaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vita'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('Vita'))),
      TextDirection.rtl,
    );
    await tester.tap(find.text('الإنجليزية'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Vita'))),
      TextDirection.ltr,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
