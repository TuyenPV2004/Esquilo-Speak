import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/user_facing_failure_localization.dart';
import '../data/p1_models.dart';
import 'p1_view_model.dart';

class AdvancedPracticeScreen extends StatefulWidget {
  const AdvancedPracticeScreen({required this.viewModel, super.key});

  final P1ViewModel viewModel;

  @override
  State<AdvancedPracticeScreen> createState() => _AdvancedPracticeScreenState();
}

class _AdvancedPracticeScreenState extends State<AdvancedPracticeScreen> {
  final _writing = TextEditingController();
  final _conversation = TextEditingController();

  @override
  void dispose() {
    _writing.dispose();
    _conversation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(strings.advancedPracticeTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                if (widget.viewModel.permissionIssue ==
                    P1PermissionIssue.microphone)
                  _FailureBanner(message: strings.microphonePermissionDenied),
                if (widget.viewModel.failure != null)
                  _FailureBanner(
                    message: widget.viewModel.failure!.localized(strings),
                  ),
                _PracticeCard(
                  icon: Icons.headphones_outlined,
                  title: strings.listeningTitle,
                  description: strings.listeningDescription,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('media-play'),
                          onPressed: widget.viewModel.busy
                              ? null
                              : () => widget.viewModel.playMedia('a1-hello'),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(strings.play),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('media-download'),
                          onPressed: widget.viewModel.busy
                              ? null
                              : () =>
                                    widget.viewModel.downloadMedia('a1-hello'),
                          icon: Icon(
                            widget.viewModel.downloadedMediaIds.contains(
                                  'a1-hello',
                                )
                                ? Icons.download_done
                                : Icons.download,
                            key:
                                widget.viewModel.downloadedMediaIds.contains(
                                  'a1-hello',
                                )
                                ? const ValueKey('media-downloaded')
                                : null,
                          ),
                          label: Text(
                            widget.viewModel.downloadedMediaIds.contains(
                                  'a1-hello',
                                )
                                ? strings.downloaded
                                : strings.download,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _PracticeCard(
                  icon: Icons.mic_none,
                  title: strings.pronunciationTitle,
                  description: strings.voiceRetentionDisclosure,
                  children: [
                    FilledButton.icon(
                      key: ValueKey(
                        widget.viewModel.recording
                            ? 'recording-stop'
                            : 'recording-start',
                      ),
                      onPressed: widget.viewModel.busy
                          ? null
                          : widget.viewModel.recording
                          ? () => widget.viewModel.stopAndAssessPronunciation(
                              expectedText: 'Hello, my name is Ana.',
                              locale: locale,
                            )
                          : widget.viewModel.startPronunciationRecording,
                      icon: Icon(
                        widget.viewModel.recording ? Icons.stop : Icons.mic,
                      ),
                      label: Text(
                        widget.viewModel.recording
                            ? strings.stopAndAssess
                            : strings.startRecording,
                      ),
                    ),
                    if (widget.viewModel.pronunciationFeedback != null)
                      _FeedbackCard(
                        feedback: widget.viewModel.pronunciationFeedback!,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _TextPracticeCard(
                  title: strings.writingTitle,
                  description: strings.writingDescription,
                  controller: _writing,
                  inputKey: 'writing-input',
                  actionKey: 'writing-submit',
                  actionLabel: strings.getFeedback,
                  busy: widget.viewModel.busy,
                  feedback: widget.viewModel.writingFeedback,
                  onChanged: (_) => setState(() {}),
                  onSubmit: () => widget.viewModel.requestTextFeedback(
                    kind: 'writing',
                    input: _writing.text.trim(),
                    locale: locale,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _TextPracticeCard(
                  title: strings.conversationTitle,
                  description: strings.conversationDescription,
                  controller: _conversation,
                  inputKey: 'conversation-input',
                  actionKey: 'conversation-submit',
                  actionLabel: strings.continueConversation,
                  busy: widget.viewModel.busy,
                  feedback: widget.viewModel.conversationFeedback,
                  onChanged: (_) => setState(() {}),
                  onSubmit: () => widget.viewModel.requestTextFeedback(
                    kind: 'conversation',
                    input: _conversation.text.trim(),
                    locale: locale,
                  ),
                ),
                if (widget.viewModel.busy)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Semantics(
                      liveRegion: true,
                      label: strings.processing,
                      child: const LinearProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextPracticeCard extends StatelessWidget {
  const _TextPracticeCard({
    required this.title,
    required this.description,
    required this.controller,
    required this.inputKey,
    required this.actionKey,
    required this.actionLabel,
    required this.busy,
    required this.feedback,
    required this.onChanged,
    required this.onSubmit,
  });

  final String title;
  final String description;
  final TextEditingController controller;
  final String inputKey;
  final String actionKey;
  final String actionLabel;
  final bool busy;
  final AdvancedFeedback? feedback;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => _PracticeCard(
    icon: Icons.edit_note,
    title: title,
    description: description,
    children: [
      TextField(
        key: ValueKey(inputKey),
        controller: controller,
        minLines: 2,
        maxLines: 5,
        maxLength: 4000,
        onChanged: onChanged,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(labelText: title, helperText: description),
      ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton(
        key: ValueKey(actionKey),
        onPressed: busy || controller.text.trim().isEmpty ? null : onSubmit,
        child: Text(actionLabel),
      ),
      if (feedback != null) _FeedbackCard(feedback: feedback!),
    ],
  );
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(description),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});

  final AdvancedFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final summary = feedback.feedback['summary']?.toString() ?? '';
    return Semantics(
      key: ValueKey('${feedback.kind}-feedback'),
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: AppRadii.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feedback.score != null)
              Text(
                '${feedback.score!.round()}/100',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            Text(summary),
          ],
        ),
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
}
