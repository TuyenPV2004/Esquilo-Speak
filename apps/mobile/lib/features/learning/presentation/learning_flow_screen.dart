import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/component_states.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../data/learning_models.dart';
import 'exercise_renderer_registry.dart';
import 'learning_view_model.dart';

class LearningFlowScreen extends StatelessWidget {
  const LearningFlowScreen({required this.viewModel, super.key});

  final LearningViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final strings = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(_title(strings))),
          body: SafeArea(
            child: ResponsiveContent(
              padding: EdgeInsets.zero,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppMotion.standard,
                child: _body(context, strings),
              ),
            ),
          ),
        );
      },
    );
  }

  String _title(AppLocalizations strings) => switch (viewModel.step) {
    LearningStep.catalog => strings.catalogTitle,
    LearningStep.courses => strings.coursesTitle,
    LearningStep.lessons => strings.lessonsTitle,
    LearningStep.lesson => strings.lessonTitle,
    LearningStep.queued => strings.offlineSavedTitle,
    LearningStep.feedback => strings.feedbackTitle,
    LearningStep.progress => strings.progressTitle,
  };

  Widget _body(BuildContext context, AppLocalizations strings) {
    if (viewModel.loading) {
      return Center(
        key: ValueKey('loading-${viewModel.step.name}'),
        child: Semantics(
          liveRegion: true,
          label: strings.loading,
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (viewModel.error != null) {
      return _ErrorState(
        message: viewModel.error!.localized(strings),
        retryLabel: strings.retry,
        onRetry: viewModel.retry,
      );
    }
    return switch (viewModel.step) {
      LearningStep.catalog => _Catalog(
        languages: viewModel.languages,
        sourceLanguage: viewModel.learningContext().sourceLanguage,
        onSelected: viewModel.chooseLanguage,
        emptyLabel: strings.empty,
      ),
      LearningStep.courses => _Courses(
        courses: viewModel.courses,
        onSelected: viewModel.chooseCourse,
        actionLabel: strings.startCourse,
        emptyLabel: strings.empty,
      ),
      LearningStep.lessons => _Lessons(
        lessons: viewModel.lessons,
        progress: viewModel.courseProgress,
        downloadStatuses: viewModel.unitDownloadStatuses,
        downloadingUnitId: viewModel.downloadingUnitId,
        onDownloadUnit: viewModel.downloadUnit,
        onSelected: viewModel.chooseLesson,
        actionLabel: strings.startLesson,
        emptyLabel: strings.empty,
        strings: strings,
      ),
      LearningStep.lesson => ExerciseRendererRegistry(
        lesson: viewModel.selectedLesson!,
        exerciseIndex: viewModel.currentExerciseIndex,
        response: viewModel.selectedResponse,
        selectionError: viewModel.selectionError == null
            ? null
            : strings.selectAnswer,
        hintVisible: viewModel.hintVisible,
        onResponse: viewModel.setResponse,
        onHint: viewModel.showHint,
        onSubmit: viewModel.submitAnswer,
        submitLabel: strings.submitAnswer,
        hintLabel: strings.showHint,
        knowLabel: strings.flashcardKnow,
        learningLabel: strings.flashcardLearning,
        moveUpLabel: strings.moveUp,
        moveDownLabel: strings.moveDown,
        unsupportedLabel: strings.destinationUnavailable,
      ),
      LearningStep.queued => AppMessageState(
        icon: Icons.cloud_done_outlined,
        message: strings.offlineSavedMessage,
        actionLabel: strings.continueLearning,
        onAction: viewModel.continueAfterQueued,
      ),
      LearningStep.feedback => _Feedback(
        feedback: viewModel.feedback!,
        actionLabel: viewModel.reviewingMistakes
            ? strings.reviewMistakes
            : viewModel.currentExerciseIndex ==
                      viewModel.selectedLesson!.exercises.length - 1 &&
                  viewModel.mistakeExerciseIndexes.isEmpty
            ? strings.viewProgress
            : strings.continueExercise,
        onContinue: viewModel.continueAfterFeedback,
      ),
      LearningStep.progress => _Progress(
        progress: viewModel.courseProgress!,
        summary: strings.completedExercises(
          viewModel.courseProgress!.completedExerciseCount,
          viewModel.courseProgress!.totalExerciseCount,
        ),
        actionLabel: strings.continueLearning,
        onContinue: viewModel.continueFromProgress,
        sessionExerciseCount: viewModel.selectedLesson?.exercises.length ?? 0,
        sessionMistakeCount: viewModel.sessionMistakeCount,
        onReturnHome: () => context.go('/home'),
      ),
    };
  }
}

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

class _Catalog extends StatelessWidget {
  const _Catalog({
    required this.languages,
    required this.sourceLanguage,
    required this.onSelected,
    required this.emptyLabel,
  });

  final List<LearningLanguage> languages;
  final String? sourceLanguage;
  final ValueChanged<LearningLanguage> onSelected;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final available = languages
        .where((item) => item.languageTag != sourceLanguage)
        .toList();
    if (available.isEmpty) return _EmptyState(label: emptyLabel);
    return ListView.separated(
      key: const ValueKey('catalog'),
      padding: const EdgeInsets.all(16),
      itemCount: available.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final language = available[index];
        return Card(
          child: ListTile(
            key: ValueKey('language-${language.languageTag}'),
            minTileHeight: 64,
            leading: const Icon(Icons.language),
            title: Text(localized(language.name, _locale(context))),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => onSelected(language),
          ),
        );
      },
    );
  }
}

class _Courses extends StatelessWidget {
  const _Courses({
    required this.courses,
    required this.onSelected,
    required this.actionLabel,
    required this.emptyLabel,
  });

  final List<Course> courses;
  final ValueChanged<Course> onSelected;
  final String actionLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return _EmptyState(label: emptyLabel);
    return ListView.builder(
      key: const ValueKey('courses'),
      padding: const EdgeInsets.all(16),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localized(
                    course.title,
                    _locale(context),
                    defaultLocale: course.locale,
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  localized(
                    course.description,
                    _locale(context),
                    defaultLocale: course.locale,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: ValueKey('course-${course.id}'),
                  onPressed: () => onSelected(course),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Lessons extends StatelessWidget {
  const _Lessons({
    required this.lessons,
    required this.progress,
    required this.downloadStatuses,
    required this.downloadingUnitId,
    required this.onDownloadUnit,
    required this.onSelected,
    required this.actionLabel,
    required this.emptyLabel,
    required this.strings,
  });

  final List<LessonSummary> lessons;
  final CourseProgress? progress;
  final Map<String, UnitDownloadStatus> downloadStatuses;
  final String? downloadingUnitId;
  final ValueChanged<String> onDownloadUnit;
  final ValueChanged<LessonSummary> onSelected;
  final String actionLabel;
  final String emptyLabel;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) return _EmptyState(label: emptyLabel);
    final groups = <String, List<LessonSummary>>{};
    for (final lesson in lessons) {
      (groups[lesson.unitId ?? 'legacy'] ??= []).add(lesson);
    }
    final completedIds =
        progress?.lessonProgress
            .where((item) => item.status == 'completed')
            .map((item) => item.lessonId)
            .toSet() ??
        const <String>{};
    return ListView.separated(
      key: const ValueKey('lessons'),
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final entry = groups.entries.elementAt(index);
        final unitLessons = entry.value;
        final first = unitLessons.first;
        final status = downloadStatuses[entry.key];
        final completedCount = unitLessons
            .where((lesson) => completedIds.contains(lesson.id))
            .length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  first.unitTitle.isEmpty
                      ? strings.unitFallbackTitle
                      : localized(
                          first.unitTitle,
                          _locale(context),
                          defaultLocale: first.locale,
                        ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(strings.unitProgress(completedCount, unitLessons.length)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: ValueKey('download-unit-${entry.key}'),
                  onPressed:
                      first.unitId == null || downloadingUnitId == entry.key
                      ? null
                      : () => onDownloadUnit(entry.key),
                  icon: downloadingUnitId == entry.key
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          status?.downloaded == true
                              ? Icons.offline_pin_outlined
                              : Icons.download_for_offline_outlined,
                        ),
                  label: Text(
                    status?.downloaded == true
                        ? strings.unitDownloaded
                        : strings.downloadUnit,
                  ),
                ),
                const SizedBox(height: 8),
                for (
                  var lessonIndex = 0;
                  lessonIndex < unitLessons.length;
                  lessonIndex++
                ) ...[
                  if (lessonIndex > 0) const Divider(),
                  _LessonTile(
                    lesson: unitLessons[lessonIndex],
                    locked:
                        lessonIndex > 0 &&
                        !completedIds.contains(unitLessons[lessonIndex - 1].id),
                    completed: completedIds.contains(
                      unitLessons[lessonIndex].id,
                    ),
                    onSelected: onSelected,
                    actionLabel: actionLabel,
                    strings: strings,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.locked,
    required this.completed,
    required this.onSelected,
    required this.actionLabel,
    required this.strings,
  });

  final LessonSummary lesson;
  final bool locked;
  final bool completed;
  final ValueChanged<LessonSummary> onSelected;
  final String actionLabel;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 72,
    leading: Icon(
      completed
          ? Icons.check_circle_outline
          : locked
          ? Icons.lock_outline
          : Icons.play_circle_outline,
    ),
    title: Text(
      localized(lesson.title, _locale(context), defaultLocale: lesson.locale),
    ),
    subtitle: Text(
      completed
          ? '${strings.minutesShort(lesson.estimatedMinutes)} · ${strings.lessonCompleted}'
          : strings.minutesShort(lesson.estimatedMinutes),
    ),
    trailing: TextButton(
      key: ValueKey('lesson-${lesson.id}'),
      onPressed: locked ? null : () => onSelected(lesson),
      child: Text(locked ? strings.lessonLocked : actionLabel),
    ),
  );
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.feedback,
    required this.actionLabel,
    required this.onContinue,
  });

  final AttemptFeedback feedback;
  final String actionLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final locale = _locale(context);
    final strings = AppLocalizations.of(context);
    final color = feedback.correct
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.errorContainer;
    return Semantics(
      liveRegion: true,
      child: ListView(
        key: const ValueKey('feedback'),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: color,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(feedback.correct ? Icons.check_circle : Icons.info),
                  const SizedBox(height: 12),
                  Text(switch (feedback.messageCode) {
                    'answer.correct' => strings.answerCorrect,
                    'answer.incorrect' => strings.answerIncorrect,
                    _ => strings.feedbackUnavailable,
                  }, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(localized(feedback.explanation, locale)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('progress-view'),
            onPressed: onContinue,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.progress,
    required this.summary,
    required this.actionLabel,
    required this.onContinue,
    required this.sessionExerciseCount,
    required this.sessionMistakeCount,
    required this.onReturnHome,
  });

  final CourseProgress progress;
  final String summary;
  final String actionLabel;
  final VoidCallback onContinue;
  final int sessionExerciseCount;
  final int sessionMistakeCount;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final total = progress.totalExerciseCount;
    final value = total == 0 ? 0.0 : progress.completedExerciseCount / total;
    return Center(
      key: const ValueKey('progress'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          label: summary,
          value: NumberFormat.percentPattern(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: value, minHeight: 12),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppLocalizations.of(context).sessionOutcomeTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).sessionOutcome(sessionExerciseCount),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        sessionMistakeCount == 0
                            ? AppLocalizations.of(context).sessionNoMistakes
                            : AppLocalizations.of(
                                context,
                              ).sessionMistakes(sessionMistakeCount),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(AppLocalizations.of(context).sessionNextStep),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('continue-from-progress'),
                onPressed: onContinue,
                child: Text(actionLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const ValueKey('return-home-from-summary'),
                onPressed: onReturnHome,
                child: Text(AppLocalizations.of(context).todayTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppMessageState(
    key: const ValueKey('error'),
    icon: Icons.cloud_off,
    message: message,
    actionLabel: retryLabel,
    onAction: onRetry,
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      AppMessageState(icon: Icons.inbox_outlined, message: label);
}
