import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/app/localization/app_strings.dart';
import 'package:vita_patient/app/providers.dart';
import 'package:vita_patient/app/theme/app_theme.dart';
import 'package:vita_patient/core/network/patient_contract.dart';
import 'package:vita_patient/features/patient/domain/models.dart';
import 'package:vita_patient/features/program/presentation/exercise_detail_screen.dart';
import 'package:vita_patient/features/program/presentation/program_screen.dart';
import 'package:vita_patient/features/progress/presentation/progress_screen.dart';
import 'exercise_repository_test.dart' show fixture;

void main() {
  const previewFont = String.fromEnvironment('UI_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isEmpty) return;
    final font = FontLoader('UiPreview')
      ..addFont(
        File(
          previewFont,
        ).readAsBytes().then((bytes) => bytes.buffer.asByteData()),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final raw = fixture('preview', 0);
  final sample = AssignedExercise.fromJson({
    ...raw,
    'customInstructionAr': 'تعليمات المعالج الخاصة بهذا التمرين.',
    'frequencyTextAr': 'حسب البرنامج المحدد لك.',
    'exercise': {
      ...raw['exercise'] as Map<String, dynamic>,
      'nameAr': 'تمرين الكتف والذراع',
      'nameEn': 'Shoulder and arm exercise',
      'descriptionAr': 'وصف توضيحي للتمرين ضمن البرنامج.',
      'executionMethodAr': 'شرح خطوات الأداء المعروضة من المعالج.',
      'warningsAr': 'تنبيهات المعالج الخاصة بالتمرين.',
      'commonMistakesAr': 'ملاحظات الأداء التي يوضحها المعالج.',
      'mediaUrl': null,
    },
  }, PatientContract({}));
  final pages = <String, Widget>{
    'program': const ProgramScreen(),
    'detail': const ExerciseDetailScreen(id: 'preview'),
    'progress': const ProgressScreen(),
  };
  for (final page in pages.entries) {
    for (final scenario in [
      ('ar', 320.0, 1.6),
      ('en', 390.0, 1.6),
      ('ar', 390.0, 1.0),
    ]) {
      testWidgets(
        '${page.key} fits ${scenario.$1} at ${scenario.$2} with ${scenario.$3} text scale',
        (tester) async {
          tester.view.physicalSize = Size(scenario.$2, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                programProvider.overrideWith((ref) async => [sample]),
                sessionsProvider.overrideWith((ref) async => []),
                dailyProvider.overrideWith(
                  (ref) async => [
                    for (var day = 13; day >= 0; day--)
                      DailyCompletion(
                        DateTime(2026, 9, 22).subtract(Duration(days: day)),
                        day % 5,
                      ),
                  ],
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light.copyWith(
                  textTheme: AppTheme.light.textTheme.apply(
                    fontFamily: previewFont.isEmpty ? null : 'UiPreview',
                  ),
                ),
                locale: Locale(scenario.$1),
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: const [
                  AppStrings.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.$3)),
                  child: child!,
                ),
                home: RepaintBoundary(key: boundary, child: page.value),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scenario.$3 == 1 && const bool.fromEnvironment('UI_PREVIEWS')) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final folder = Directory('build/ui-preview')
                ..createSync(recursive: true);
              await File(
                '${folder.path}/${page.key}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -1500),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
