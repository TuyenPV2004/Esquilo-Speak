import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';

class AdvancedLearningHubScreen extends StatelessWidget {
  const AdvancedLearningHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final destinations = [
      (
        key: 'advanced-practice-entry',
        icon: Icons.record_voice_over_outlined,
        title: strings.advancedPracticeTitle,
        description: strings.advancedPracticeDescription,
        route: '/home/advanced/practice',
      ),
      (
        key: 'placement-entry',
        icon: Icons.fact_check_outlined,
        title: strings.placementTitle,
        description: strings.placementDescription,
        route: '/home/advanced/placement',
      ),
      (
        key: 'engagement-entry',
        icon: Icons.local_fire_department_outlined,
        title: strings.engagementTitle,
        description: strings.engagementDescription,
        route: '/home/advanced/engagement',
      ),
      (
        key: 'premium-entry',
        icon: Icons.workspace_premium_outlined,
        title: strings.premiumTitle,
        description: strings.premiumDescription,
        route: '/home/advanced/premium',
      ),
      (
        key: 'support-entry',
        icon: Icons.support_agent_outlined,
        title: strings.supportTitle,
        description: strings.supportDescription,
        route: '/home/advanced/support',
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(strings.advancedLearningTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: destinations.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    strings.advancedLearningDescription,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }
              final destination = destinations[index - 1];
              return Card(
                child: ListTile(
                  key: ValueKey(destination.key),
                  minTileHeight: 80,
                  leading: Icon(destination.icon),
                  title: Text(destination.title),
                  subtitle: Text(destination.description),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => context.push(destination.route),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
