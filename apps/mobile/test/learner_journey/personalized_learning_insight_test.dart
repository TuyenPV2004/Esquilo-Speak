import 'package:esquilospeak_mobile/features/home/presentation/learning_recommendation_card.dart';
import 'package:esquilospeak_mobile/features/review/data/learning_insights_models.dart';
import 'package:esquilospeak_mobile/features/review/presentation/review_screen.dart';
import 'package:esquilospeak_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains a due-review recommendation at large text', (
    tester,
  ) async {
    var openedReview = false;
    await tester.pumpWidget(
      _TestApp(
        child: LearningRecommendationCard(
          recommendation: const LearningRecommendation(
            algorithmVersion: 1,
            kind: LearningRecommendationKind.reviewDue,
            conceptId: 'greeting.hello',
            masteryScore: 0.5,
          ),
          onOpenLearning: () {},
          onOpenReview: () => openedReview = true,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('learning-recommendation')),
      findsOneWidget,
    );
    expect(find.text('Review greeting.hello'), findsOneWidget);
    expect(find.text('Why this is recommended'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('recommendation-action')),
    );
    await tester.tap(find.byKey(const ValueKey('recommendation-action')));
    await tester.pump();

    expect(openedReview, isTrue);
  });

  testWidgets('expands an explainable mastery insight at large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _TestApp(
        child: MasteryInsightCard(
          item: MasteryState(
            conceptId: 'greeting.hello',
            modelVersion: 1,
            score: 0.5,
            correctEvidenceCount: 1,
            evidenceCount: 2,
            lastEvidenceAt: DateTime.utc(2026, 7, 30, 8, 30),
            calculationMethod: 'weighted-correct-ratio',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1 correct from 2 evidence'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('mastery-insight-greeting.hello')),
    );
    await tester.pumpAndSettle();

    expect(find.text('How this score is calculated'), findsOneWidget);
    expect(find.text('Model version 1'), findsOneWidget);
    expect(find.textContaining('Each accepted answer'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(400, 700),
        textScaler: TextScaler.linear(2),
      ),
      child: Scaffold(
        body: SafeArea(child: SingleChildScrollView(child: child)),
      ),
    ),
  );
}
