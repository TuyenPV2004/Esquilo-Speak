import 'package:esquilospeak_mobile/core/design_system/app_theme.dart';
import 'package:esquilospeak_mobile/features/advanced_learning/presentation/advanced_learning_hub_screen.dart';
import 'package:esquilospeak_mobile/features/advanced_learning/presentation/advanced_practice_screen.dart';
import 'package:esquilospeak_mobile/features/advanced_learning/presentation/p1_view_model.dart';
import 'package:esquilospeak_mobile/features/assessment/presentation/placement_screen.dart';
import 'package:esquilospeak_mobile/features/commerce/presentation/premium_screen.dart';
import 'package:esquilospeak_mobile/features/engagement/presentation/engagement_screen.dart';
import 'package:esquilospeak_mobile/features/support/presentation/support_screen.dart';
import 'package:esquilospeak_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/p1_fakes.dart';

void main() {
  testWidgets('advanced hub and practice remain accessible at large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final viewModel = _viewModel();
    await viewModel.load();
    await tester.pumpWidget(
      _TestApp(child: AdvancedPracticeScreen(viewModel: viewModel)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('media-play')), findsOneWidget);
    await _scrollTo(tester, find.byKey(const ValueKey('writing-input')));
    await tester.enterText(
      find.byKey(const ValueKey('writing-input')),
      'Hello, my name is Ana.',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const ValueKey('writing-submit')));
    await tester.tap(find.byKey(const ValueKey('writing-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Clear response with enough detail.'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('placement answers all questions and shows completion result', (
    tester,
  ) async {
    final viewModel = _viewModel();
    await viewModel.load();
    await tester.pumpWidget(
      _TestApp(child: PlacementScreen(viewModel: viewModel)),
    );

    for (final question in viewModel.assessment!.questions) {
      final answer = question.options.first;
      final finder = find.byKey(
        ValueKey('placement-${question.id}-${answer.id}'),
      );
      await _scrollTo(tester, finder);
      await tester.tap(finder);
      await tester.pump();
    }
    await _scrollTo(tester, find.byKey(const ValueKey('placement-submit')));
    await tester.tap(find.byKey(const ValueKey('placement-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('placement-result')), findsOneWidget);
    expect(find.textContaining('non-accredited'), findsOneWidget);
  });

  testWidgets('placement content uses target locale when UI is Vietnamese', (
    tester,
  ) async {
    final viewModel = _viewModel();
    await viewModel.load();
    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('vi'),
        child: PlacementScreen(viewModel: viewModel),
      ),
    );

    expect(find.text('Xếp trình độ'), findsOneWidget);
    expect(find.text('Complete: My ___ is Ana.'), findsOneWidget);
    expect(find.text('name'), findsOneWidget);
    expect(find.text('day'), findsOneWidget);
    expect(find.text('food'), findsOneWidget);
    expect(find.text('Hoàn thành: My ___ is Ana.'), findsNothing);
    expect(find.text('tên'), findsNothing);
    expect(find.text('ngày'), findsNothing);
    expect(find.text('đồ ăn'), findsNothing);
  });

  testWidgets('engagement and premium expose closed-testing lifecycle', (
    tester,
  ) async {
    final viewModel = _viewModel();
    await viewModel.load();
    await viewModel.requestTextFeedback(
      kind: 'writing',
      input: 'Hello, my name is Ana.',
      locale: 'en',
    );
    await tester.pumpWidget(
      _TestApp(child: EngagementScreen(viewModel: viewModel)),
    );
    await tester.tap(find.byKey(const ValueKey('engagement-activity')));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget);

    await tester.pumpWidget(
      _TestApp(child: PremiumScreen(viewModel: viewModel)),
    );
    await _scrollTo(tester, find.byKey(const ValueKey('premium-purchase')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('premium-purchase')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('premium-purchase')));
    await tester.pumpAndSettle();
    expect(viewModel.entitlement?.active, isTrue);
    await _scrollTo(tester, find.byKey(const ValueKey('premium-entitlement')));
    expect(find.text('Premium entitlement is active'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const ValueKey('premium-refund')));
    await tester.tap(find.byKey(const ValueKey('premium-refund')));
    await tester.pumpAndSettle();
    expect(find.text('Premium entitlement is revoked'), findsOneWidget);
  });

  testWidgets('support flow validates input and confirms ticket state', (
    tester,
  ) async {
    final viewModel = _viewModel();
    await tester.pumpWidget(
      _TestApp(child: SupportScreen(viewModel: viewModel)),
    );

    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('support-submit')),
    );
    expect(submit.onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('support-description')),
      'Please help with this lesson.',
    );
    await _scrollTo(tester, find.byKey(const ValueKey('support-submit')));
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const ValueKey('support-success')));
    expect(find.byKey(const ValueKey('support-success')), findsOneWidget);
    expect(find.text('Status: Open'), findsOneWidget);
  });

  testWidgets('hub provides all five discoverable P1 destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestApp(child: AdvancedLearningHubScreen()));
    for (final key in [
      'advanced-practice-entry',
      'placement-entry',
      'engagement-entry',
      'premium-entry',
      'support-entry',
    ]) {
      final finder = find.byKey(ValueKey(key));
      await _scrollTo(tester, finder);
      expect(finder, findsOneWidget);
    }
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

P1ViewModel _viewModel() => P1ViewModel(
  FakeP1Gateway(),
  FakeAdvancedLearningPlatform(),
  closedTestingCommerceEnabled: true,
  closedTestingProductId: 'premium-monthly',
  selectedCourseId: () => 'course-en-for-vi',
);

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.locale = const Locale('en')});

  final Widget child;
  final Locale locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: locale,
    theme: AppTheme.light(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(400, 800),
        textScaler: TextScaler.linear(2),
      ),
      child: child,
    ),
  );
}
