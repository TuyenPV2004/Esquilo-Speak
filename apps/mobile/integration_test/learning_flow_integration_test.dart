import 'package:esquilospeak_mobile/app/esquilo_speak_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes the live Android learning journey', (tester) async {
    await tester.pumpWidget(const EsquiloSpeakApp());

    await _waitFor(tester, find.byKey(const ValueKey('language-en')));
    await tester.tap(find.byKey(const ValueKey('language-en')));

    await _waitFor(
      tester,
      find.byKey(const ValueKey('course-course-en-for-vi')),
    );
    await tester.tap(find.byKey(const ValueKey('course-course-en-for-vi')));

    await _waitFor(
      tester,
      find.byKey(const ValueKey('lesson-lesson-basic-greetings')),
    );
    await tester.tap(
      find.byKey(const ValueKey('lesson-lesson-basic-greetings')),
    );

    await _waitFor(tester, find.byKey(const ValueKey('option-option-hello')));
    await tester.tap(find.byKey(const ValueKey('option-option-hello')));
    await tester.tap(find.byKey(const ValueKey('attempt-submit')));

    await _waitFor(tester, find.byKey(const ValueKey('progress-view')));
    await tester.tap(find.byKey(const ValueKey('progress-view')));

    await _waitFor(tester, find.byKey(const ValueKey('progress')));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
}
