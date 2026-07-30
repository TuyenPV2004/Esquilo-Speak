import 'package:esquilospeak_mobile/app/esquilo_speak_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes the live Android learning journey', (tester) async {
    await tester.pumpWidget(const EsquiloSpeakApp());

    await _waitForAny(tester, [
      find.byKey(const ValueKey('sign-in')),
      find.byKey(const ValueKey('retry-profile')),
      find.byKey(const ValueKey('age-adult')),
      find.byKey(const ValueKey('recommendation-action')),
    ], timeout: const Duration(seconds: 60));
    if (find.byKey(const ValueKey('retry-profile')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('retry-profile')));
      await _waitForAny(tester, [
        find.byKey(const ValueKey('sign-in')),
        find.byKey(const ValueKey('age-adult')),
        find.byKey(const ValueKey('recommendation-action')),
      ]);
    }
    if (find.byKey(const ValueKey('sign-in')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('sign-in')));
      await _waitForAny(tester, [
        find.byKey(const ValueKey('age-adult')),
        find.byKey(const ValueKey('recommendation-action')),
      ]);
    }
    if (find.byKey(const ValueKey('age-adult')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('age-adult')));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('complete-onboarding')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('complete-onboarding')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey('recommendation-action')),
      );
    }
    expect(
      find.byKey(const ValueKey('learning-recommendation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('recommendation-action')));

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

Future<void> _waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finders.every((finder) => finder.evaluate().isEmpty) &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
  }
  if (finders.every((finder) => finder.evaluate().isEmpty)) {
    final bootstrapFailed = find
        .textContaining('could not start')
        .evaluate()
        .isNotEmpty;
    final stillLoading = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;
    final visibleKeys =
        find
            .byWidgetPredicate((widget) => widget.key != null)
            .evaluate()
            .map((element) => element.widget.key.toString())
            .toSet()
            .toList()
          ..sort();
    fail(
      'Timed out waiting for the learner journey '
      '(bootstrapFailed: $bootstrapFailed, stillLoading: $stillLoading, '
      'visibleKeys: $visibleKeys).',
    );
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}
