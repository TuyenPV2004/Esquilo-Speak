import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../advanced_learning/presentation/p1_view_model.dart';
import '../../learning/data/learning_models.dart';
import '../../learning/presentation/learning_view_model.dart';

class PlacementScreen extends StatefulWidget {
  const PlacementScreen({
    required this.viewModel,
    this.learningViewModel,
    super.key,
  });

  final P1ViewModel viewModel;
  final LearningViewModel? learningViewModel;

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.loadPlacement();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final viewModel = widget.viewModel;
    return Scaffold(
      appBar: AppBar(title: Text(strings.placementTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              final result = viewModel.placementResult;
              if (result != null) {
                final formattedScore = NumberFormat.percentPattern(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(result.score / 100);
                final points = _availableStartPoints(result.score);
                return ListView(
                  key: const ValueKey('placement-result'),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  children: [
                    AppMessageState(
                      icon: result.passed
                          ? Icons.verified_outlined
                          : Icons.school_outlined,
                      message: result.passed
                          ? strings.placementPassed(
                              formattedScore,
                              result.proficiency.levelCode,
                            )
                          : strings.placementNotPassed(
                              formattedScore,
                              result.proficiency.levelCode,
                            ),
                      actionLabel: strings.tryAgain,
                      onAction: viewModel.resetPlacement,
                    ),
                    if (points.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        strings.placementChooseStart,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(strings.placementLowerLevelNotice),
                      const SizedBox(height: AppSpacing.sm),
                      for (final point in points)
                        Card(
                          child: ListTile(
                            key: ValueKey('placement-start-${point.lessonId}'),
                            title: Text(
                              resolveLocalizedText(
                                point.title,
                                Localizations.localeOf(context).toLanguageTag(),
                                defaultLocale: 'vi',
                              ),
                            ),
                            subtitle: Text(point.levelCode),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () async {
                              await widget.learningViewModel!.startAtLesson(
                                point.lessonId,
                              );
                              if (context.mounted) context.go('/learn');
                            },
                          ),
                        ),
                    ],
                  ],
                );
              }
              final assessment = viewModel.assessment;
              if (assessment == null) {
                return AppMessageState(
                  icon: Icons.cloud_download_outlined,
                  message: viewModel.courseSelectionRequired
                      ? strings.placementCourseRequired
                      : strings.placementLoading,
                  actionLabel: strings.retry,
                  onAction: viewModel.loadPlacement,
                );
              }
              final allAnswered = assessment.questions.every(
                (question) =>
                    viewModel.assessmentAnswers.containsKey(question.id),
              );
              final assessmentLocale = assessment.defaultLocale;
              return ListView(
                key: const ValueKey('placement-assessment'),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                children: [
                  Text(
                    strings.placementInternalNotice,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${assessment.proficiency.frameworkCode.toUpperCase()} '
                    '${assessment.proficiency.levelCode}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...assessment.questions.indexed.map((entry) {
                    final index = entry.$1;
                    final question = entry.$2;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                strings.questionNumber(index + 1),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                resolveLocalizedText(
                                  question.prompt,
                                  assessmentLocale,
                                  defaultLocale: assessment.defaultLocale,
                                ),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              RadioGroup<String>(
                                groupValue:
                                    viewModel.assessmentAnswers[question.id],
                                onChanged: (value) {
                                  if (value != null) {
                                    viewModel.selectAssessmentAnswer(
                                      question.id,
                                      value,
                                    );
                                  }
                                },
                                child: Column(
                                  children: question.options
                                      .map(
                                        (option) => RadioListTile<String>(
                                          key: ValueKey(
                                            'placement-${question.id}-${option.id}',
                                          ),
                                          value: option.id,
                                          title: Text(
                                            resolveLocalizedText(
                                              option.text,
                                              assessmentLocale,
                                              defaultLocale:
                                                  assessment.defaultLocale,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  FilledButton(
                    key: const ValueKey('placement-submit'),
                    onPressed: viewModel.busy || !allAnswered
                        ? null
                        : viewModel.submitPlacement,
                    child: Text(
                      viewModel.busy ? strings.processing : strings.submit,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<PlacementStartPoint> _availableStartPoints(int score) {
    return widget.learningViewModel?.placementStartPointsForScore(score) ??
        const <PlacementStartPoint>[];
  }
}
