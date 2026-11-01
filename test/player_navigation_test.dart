import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/features/program/presentation/program_screen.dart';

void main() {
  test('detail actions request direct start while session entry does not', () {
    final direct = Uri.parse(
      playerLocation(
        startId: 'assignment / 1',
        sessionId: 'session-1',
        autoStart: true,
      ),
    );
    expect(direct.path, '/play');
    expect(direct.queryParameters, {
      'start': 'assignment / 1',
      'session': 'session-1',
      'auto': '1',
    });

    final prepared = Uri.parse(playerLocation(startId: 'assignment-2'));
    expect(prepared.queryParameters['auto'], isNull);
  });
}
