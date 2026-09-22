import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/app/config/app_config.dart';
import 'package:vita_patient/app/localization/app_strings.dart';
import 'package:vita_patient/app/providers.dart';
import 'package:vita_patient/app/theme/app_theme.dart';
import 'package:vita_patient/core/network/api_client.dart';
import 'package:vita_patient/features/auth/presentation/auth_screen.dart';
import 'core/network_test.dart' show MemoryTokens, TestAdapter, rejected;

void main() {
  testWidgets(
    'registration validates required fields on a narrow RTL display',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0;
      final dio = Dio();
      dio.httpClientAdapter = TestAdapter((_) async {
        requests++;
        return rejected('INVALID_CREDENTIALS');
      });
      final api = ApiClient(baseUrl: '', store: MemoryTokens(), transport: dio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configProvider.overrideWithValue(
              const AppConfig(
                gateway: 'https://clinic.test',
                environment: Environment.staging,
              ),
            ),
            apiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const AuthScreen(register: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.byType(FilledButton);
      await tester.scrollUntilVisible(
        submit.hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(submit.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('هذا الحقل مطلوب'), findsNWidgets(3));
      expect(requests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
