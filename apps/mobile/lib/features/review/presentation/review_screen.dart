import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import 'learning_insights_view_model.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({required this.viewModel, super.key});

  final LearningInsightsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.reviewTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              if (viewModel.loading && viewModel.insights == null) {
                return AppLoadingState(label: strings.loadingProgress);
              }
              if (viewModel.failure != null && viewModel.insights == null) {
                return AppMessageState(
                  icon: Icons.cloud_off_outlined,
                  message: viewModel.failure!.localized(strings),
                  actionLabel: strings.retry,
                  onAction: viewModel.load,
                );
              }
              final insights = viewModel.insights;
              if (insights == null ||
                  (insights.reviews.isEmpty && insights.mastery.isEmpty)) {
                return AppMessageState(
                  icon: Icons.task_alt,
                  message: strings.reviewEmpty,
                  actionLabel: strings.refresh,
                  onAction: viewModel.load,
                );
              }
              return RefreshIndicator(
                onRefresh: viewModel.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (insights.fromCache)
                      Semantics(
                        liveRegion: true,
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.offline_bolt_outlined),
                            title: Text(strings.showingOfflineData),
                          ),
                        ),
                      ),
                    Text(
                      strings.dueReviewHeading(insights.reviews.length),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...insights.reviews.map(
                      (item) => Card(
                        child: ListTile(
                          leading: Icon(
                            item.lastResult == 'correct'
                                ? Icons.check_circle_outline
                                : Icons.replay_circle_filled_outlined,
                          ),
                          title: Text(item.conceptId),
                          subtitle: Text(
                            strings.reviewInterval(item.intervalDays),
                          ),
                          trailing: Text(
                            strings.reviewRepetitions(item.repetitions),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      strings.masteryHeading,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...insights.mastery.map(
                      (item) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Semantics(
                            label: strings.masteryValue(
                              item.conceptId,
                              (item.score * 100).round(),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  item.conceptId,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                LinearProgressIndicator(value: item.score),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  strings.masteryEvidence(
                                    item.correctEvidenceCount,
                                    item.evidenceCount,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
