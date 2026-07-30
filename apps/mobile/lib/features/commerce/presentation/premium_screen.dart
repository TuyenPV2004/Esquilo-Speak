import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/responsive_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../advanced_learning/presentation/p1_view_model.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({required this.viewModel, super.key});

  final P1ViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.premiumTitle)),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              final entitlement = viewModel.entitlement;
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.workspace_premium_outlined,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            strings.premiumPlanTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            strings.premiumPlanBenefits,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            strings.closedTestingPrice,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            key: const ValueKey('premium-purchase'),
                            onPressed:
                                viewModel.busy ||
                                    !viewModel.closedTestingCommerceEnabled
                                ? null
                                : viewModel.purchasePremium,
                            child: Text(
                              viewModel.busy
                                  ? strings.processing
                                  : strings.activatePremium,
                            ),
                          ),
                          if (!viewModel.closedTestingCommerceEnabled)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(strings.playBillingRequired),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (entitlement != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Card(
                        color: entitlement.active
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        child: ListTile(
                          key: const ValueKey('premium-entitlement'),
                          leading: Icon(
                            entitlement.active
                                ? Icons.verified
                                : Icons.block_outlined,
                          ),
                          title: Text(
                            entitlement.active
                                ? strings.premiumActive
                                : strings.premiumRevoked,
                          ),
                        ),
                      ),
                    ),
                    if (entitlement.active)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: OutlinedButton(
                          key: const ValueKey('premium-refund'),
                          onPressed: viewModel.busy
                              ? null
                              : viewModel.refundPremium,
                          child: Text(strings.simulateRefund),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
