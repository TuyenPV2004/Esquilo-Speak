import 'package:esquilospeak_mobile/app/esquilo_speak_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    await _completeAdvancedLearning(tester);
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

Future<void> _completeAdvancedLearning(WidgetTester tester) async {
  await _tapVisible(tester, const ValueKey('advanced-learning-entry'));
  await _waitFor(tester, find.byKey(const ValueKey('advanced-practice-entry')));

  await _tapVisible(tester, const ValueKey('advanced-practice-entry'));
  await _waitFor(tester, find.byKey(const ValueKey('media-download')));
  await tester.tap(find.byKey(const ValueKey('media-download')));
  await _waitFor(tester, find.byKey(const ValueKey('media-downloaded')));
  await _tapVisible(tester, const ValueKey('writing-input'));
  await tester.enterText(
    find.byKey(const ValueKey('writing-input')),
    'Hello, I am learning English today.',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await _tapVisible(tester, const ValueKey('writing-submit'));
  await _waitFor(tester, find.byKey(const ValueKey('writing-feedback')));

  await _goTo(tester, '/home/advanced/placement');
  await _waitFor(tester, find.byKey(const ValueKey('placement-assessment')));
  for (final key in const [
    'placement-a1-greeting-hello',
    'placement-a1-name-name',
    'placement-a1-number-three',
    'placement-a1-goodbye-goodbye',
  ]) {
    await _tapVisible(tester, ValueKey(key));
  }
  await _tapVisible(tester, const ValueKey('placement-submit'));
  await _waitFor(tester, find.byKey(const ValueKey('placement-result')));

  await _goTo(tester, '/home/advanced/premium');
  await _tapVisible(tester, const ValueKey('premium-purchase'));
  await _waitFor(tester, find.byKey(const ValueKey('premium-entitlement')));
  await _tapVisible(tester, const ValueKey('premium-refund'));
  await _waitFor(tester, find.byIcon(Icons.block_outlined));

  await _goTo(tester, '/home/advanced/support');
  await _tapVisible(tester, const ValueKey('support-description'));
  await tester.enterText(
    find.byKey(const ValueKey('support-description')),
    'Please help me review this closed-testing learning flow.',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await _tapVisible(tester, const ValueKey('support-submit'));
  await _waitFor(tester, find.byKey(const ValueKey('support-success')));

  await _goTo(tester, '/home');
  await _waitFor(tester, find.byKey(const ValueKey('recommendation-action')));
}

Future<void> _goTo(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).last);
  GoRouter.of(context).go(location);
  await tester.pump();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      350,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
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
