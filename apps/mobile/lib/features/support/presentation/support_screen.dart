import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../advanced_learning/presentation/p1_view_model.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({required this.viewModel, super.key});

  final P1ViewModel viewModel;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _description = TextEditingController();
  final _contentRef = TextEditingController();
  bool _contentReport = false;

  @override
  void dispose() {
    _description.dispose();
    _contentRef.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(strings.supportTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.support_agent_outlined),
                      label: Text(strings.supportRequest),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(strings.contentReport),
                    ),
                  ],
                  selected: {_contentReport},
                  onSelectionChanged: (selection) {
                    setState(() => _contentReport = selection.single);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_contentReport)
                  TextField(
                    key: const ValueKey('support-content-ref'),
                    controller: _contentRef,
                    decoration: InputDecoration(
                      labelText: strings.contentReference,
                    ),
                  ),
                if (_contentReport) const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('support-description'),
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: strings.supportMessage,
                    helperText: strings.supportPrivacyNote,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const ValueKey('support-submit'),
                  onPressed:
                      widget.viewModel.busy ||
                          _description.text.trim().isEmpty ||
                          (_contentReport && _contentRef.text.trim().isEmpty)
                      ? null
                      : () => widget.viewModel.submitSupport(
                          contentReport: _contentReport,
                          contentRef: _contentRef.text.trim(),
                          locale: locale,
                          description: _description.text.trim(),
                        ),
                  child: Text(
                    widget.viewModel.busy
                        ? strings.processing
                        : strings.sendRequest,
                  ),
                ),
                if (widget.viewModel.supportTicket != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: ListTile(
                          key: const ValueKey('support-success'),
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(strings.supportSubmitted),
                          subtitle: Text(
                            strings.supportTicketStatus(
                              widget.viewModel.supportTicket!.status,
                            ),
                          ),
                        ),
                      ),
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
