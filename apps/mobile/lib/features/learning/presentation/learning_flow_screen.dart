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
  const LearningFlowScreen({
    required this.viewModel,
    this.onPlayMedia,
    this.onDownloadMedia,
    super.key,
  });

  final LearningViewModel viewModel;
  final Future<void> Function(String mediaId)? onPlayMedia;
  final Future<void> Function(String mediaId)? onDownloadMedia;

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
        course: viewModel.selectedCourse,
        courseDownloadStatus: viewModel.courseDownloadStatus,
        downloadingCourse: viewModel.downloadingCourse,
        onDownloadCourse: () =>
            viewModel.downloadCourse(downloadMedia: onDownloadMedia),
        onDownloadUnit: viewModel.downloadUnit,
        onSelected: viewModel.chooseLesson,
        actionLabel: strings.startLesson,
        emptyLabel: strings.empty,
        strings: strings,
      ),
      LearningStep.lesson => _exercise(strings),
      LearningStep.queued => AppMessageState(
        icon: Icons.cloud_done_outlined,
        message: strings.offlineSavedMessage,
        actionLabel: strings.continueLearning,
        onAction: viewModel.continueAfterQueued,
      ),
      LearningStep.feedback => _Feedback(
        feedback: viewModel.feedback!,
        helpfulnessRecorded: viewModel.feedbackHelpfulnessRecorded,
        helpfulnessQuestion: strings.feedbackHelpfulQuestion,
        helpfulLabel: strings.feedbackHelpfulYes,
        notHelpfulLabel: strings.feedbackHelpfulNo,
        helpfulnessThanks: strings.feedbackHelpfulThanks,
        onHelpfulness: viewModel.recordFeedbackHelpfulness,
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
        summary: viewModel.sessionKind == LearningSessionKind.practice
            ? strings.practiceScore(
                viewModel.sessionCorrectCount,
                viewModel.selectedLesson?.exercises.length ?? 0,
              )
            : strings.completedExercises(
                viewModel.courseProgress!.completedExerciseCount,
                viewModel.courseProgress!.totalExerciseCount,
              ),
        actionLabel: strings.continueLearning,
        onContinue: viewModel.continueFromProgress,
        sessionExerciseCount: viewModel.selectedLesson?.exercises.length ?? 0,
        sessionMistakeCount: viewModel.sessionMistakeCount,
        practiceCorrectCount: viewModel.sessionCorrectCount,
        isPractice: viewModel.sessionKind == LearningSessionKind.practice,
        onReturnHome: () => context.go('/home'),
      ),
    };
  }

  Widget _exercise(AppLocalizations strings) {
    final mediaId = viewModel.currentExerciseMediaId;
    final renderer = ExerciseRendererRegistry(
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
      flashcardRevealed: viewModel.flashcardRevealed,
      onFlashcardFlip: viewModel.flipFlashcard,
      flipCardLabel: strings.flipCard,
      cardBackLabel: strings.cardBack,
      playAudioLabel: strings.playAudio,
      onPlayAudio: mediaId == null || onPlayMedia == null
          ? null
          : () {
              onPlayMedia!(mediaId);
            },
    );
    if (viewModel.sessionKind != LearningSessionKind.practice) return renderer;
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ListTile(
            leading: const Icon(Icons.psychology_alt_outlined),
            title: Text(_practiceReason(strings)),
            trailing: viewModel.activePracticeMode?.apiValue == 'flashcards'
                ? IconButton(
                    tooltip: strings.shuffleCards,
                    onPressed: viewModel.shufflePractice,
                    icon: const Icon(Icons.shuffle),
                  )
                : null,
          ),
        ),
        Expanded(child: renderer),
      ],
    );
  }

  String _practiceReason(AppLocalizations strings) =>
      viewModel.practiceUsedFallback
      ? strings.practiceReasonFallback
      : switch (viewModel.practiceExplanationCode) {
          'practice_reason_flashcards' => strings.practiceReasonFlashcards,
          'practice_reason_adaptive' => strings.practiceReasonAdaptive,
          'practice_reason_test' => strings.practiceReasonTest,
          'practice_reason_match' => strings.practiceReasonMatch,
          'practice_reason_mistakes' => strings.practiceReasonMistakes,
          'practice_reason_weak' => strings.practiceReasonWeak,
          _ => strings.practiceReasonFallback,
        };
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
    required this.course,
    required this.courseDownloadStatus,
    required this.downloadingCourse,
    required this.onDownloadCourse,
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
  final Course? course;
  final CourseDownloadStatus? courseDownloadStatus;
  final bool downloadingCourse;
  final VoidCallback onDownloadCourse;
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
      itemCount: groups.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          final policy = course?.offlinePackagePolicy;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.offlineCourseTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    policy == null
                        ? strings.offlineCourseDescription
                        : strings.offlineCoursePolicy(
                            policy.packageVersion,
                            (policy.maxBytes / 1048576).ceil(),
                            policy.cacheTtlDays,
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('download-course'),
                    onPressed: downloadingCourse ? null : onDownloadCourse,
                    icon: downloadingCourse
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            courseDownloadStatus?.downloaded == true
                                ? Icons.offline_pin_outlined
                                : Icons.download_for_offline_outlined,
                          ),
                    label: Text(
                      courseDownloadStatus?.downloaded == true
                          ? strings.courseDownloaded
                          : strings.downloadCourse,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final entry = groups.entries.elementAt(index - 1);
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
                if (first.unitGuidebook != null) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: ValueKey('guidebook-${entry.key}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(strings.unitGuidebook),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          localized(
                            first.unitGuidebook!.summary,
                            _locale(context),
                            defaultLocale: first.locale,
                          ),
                        ),
                      ),
                      for (final phrase in first.unitGuidebook!.keyPhrases)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(
                            localized(
                              phrase,
                              _locale(context),
                              defaultLocale: first.locale,
                            ),
                          ),
                        ),
                      for (final note in first.unitGuidebook!.grammarNotes)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(
                            localized(
                              note,
                              _locale(context),
                              defaultLocale: first.locale,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
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
    required this.helpfulnessRecorded,
    required this.helpfulnessQuestion,
    required this.helpfulLabel,
    required this.notHelpfulLabel,
    required this.helpfulnessThanks,
    required this.onHelpfulness,
  });

  final AttemptFeedback feedback;
  final String actionLabel;
  final VoidCallback onContinue;
  final bool helpfulnessRecorded;
  final String helpfulnessQuestion;
  final String helpfulLabel;
  final String notHelpfulLabel;
  final String helpfulnessThanks;
  final ValueChanged<bool> onHelpfulness;

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
          if (helpfulnessRecorded)
            Semantics(liveRegion: true, child: Text(helpfulnessThanks))
          else ...[
            Text(
              helpfulnessQuestion,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('feedback-helpful-yes'),
                  onPressed: () => onHelpfulness(true),
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: Text(helpfulLabel),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('feedback-helpful-no'),
                  onPressed: () => onHelpfulness(false),
                  icon: const Icon(Icons.thumb_down_outlined),
                  label: Text(notHelpfulLabel),
                ),
              ],
            ),
          ],
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
    required this.practiceCorrectCount,
    required this.isPractice,
  });

  final CourseProgress progress;
  final String summary;
  final String actionLabel;
  final VoidCallback onContinue;
  final int sessionExerciseCount;
  final int sessionMistakeCount;
  final VoidCallback onReturnHome;
  final int practiceCorrectCount;
  final bool isPractice;

  @override
  Widget build(BuildContext context) {
    final total = progress.totalExerciseCount;
    final value = isPractice
        ? (sessionExerciseCount == 0
              ? 0.0
              : practiceCorrectCount / sessionExerciseCount)
        : total == 0
        ? 0.0
        : progress.completedExerciseCount / total;
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
              if (!isPractice &&
                  total > 0 &&
                  progress.completedExerciseCount == total) ...[
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(
                      AppLocalizations.of(context).courseCompletionTitle,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      ).courseCompletionNonAccredited,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
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
