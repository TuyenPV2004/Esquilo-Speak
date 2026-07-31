import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/localization/localized_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../review/data/learning_insights_models.dart';

class LearningRecommendationCard extends StatelessWidget {
  const LearningRecommendationCard({
    required this.recommendation,
    required this.onOpenLearning,
    required this.onOpenReview,
    super.key,
  });

  final LearningRecommendation recommendation;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenReview;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final copy = _copy(
      strings,
      Localizations.localeOf(context).toLanguageTag(),
    );
    final opensReview =
        recommendation.kind == LearningRecommendationKind.reviewDue;
    return Card(
      key: const ValueKey('learning-recommendation'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                copy.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.recommendationReasonLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(copy.reason),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('recommendation-action'),
              onPressed: opensReview ? onOpenReview : onOpenLearning,
              icon: Icon(
                opensReview
                    ? Icons.event_repeat_outlined
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                opensReview
                    ? strings.openReviewQueue
                    : strings.continueLearning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _RecommendationCopy _copy(AppLocalizations strings, String locale) {
    final conceptTitle = recommendation.conceptTitle == null
        ? ''
        : resolveLocalizedText(
            recommendation.conceptTitle!,
            locale,
            defaultLocale: recommendation.defaultLocale,
          );
    return switch (recommendation.kind) {
      LearningRecommendationKind.reviewDue => _RecommendationCopy(
        strings.recommendedReviewTitle(conceptTitle),
        strings.recommendedReviewReason,
      ),
      LearningRecommendationKind.strengthenWeakConcept => _RecommendationCopy(
        strings.recommendedPracticeTitle(conceptTitle),
        strings.recommendedPracticeReason(
          NumberFormat.percentPattern(
            locale,
          ).format(recommendation.masteryScore ?? 0),
        ),
      ),
      LearningRecommendationKind.continueLearning => _RecommendationCopy(
        strings.recommendedContinueTitle,
        strings.recommendedContinueReason,
      ),
      LearningRecommendationKind.startLearning => _RecommendationCopy(
        strings.recommendedStartTitle,
        strings.recommendedStartReason,
      ),
    };
  }
}

class _RecommendationCopy {
  const _RecommendationCopy(this.title, this.reason);

  final String title;
  final String reason;
}
