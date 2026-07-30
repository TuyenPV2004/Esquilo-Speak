import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_dependencies.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/advanced_learning/presentation/advanced_learning_hub_screen.dart';
import '../../features/advanced_learning/presentation/advanced_practice_screen.dart';
import '../../features/assessment/presentation/placement_screen.dart';
import '../../features/commerce/presentation/premium_screen.dart';
import '../../features/engagement/presentation/engagement_screen.dart';
import '../../features/learning/presentation/learning_flow_screen.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/welcome_screen.dart';
import '../../features/review/presentation/review_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../l10n/app_localizations.dart';
import 'learner_shell.dart';

GoRouter createAppRouter(AppDependencies dependencies) => GoRouter(
  initialLocation: '/',
  refreshListenable: dependencies.profileViewModel,
  redirect: (context, state) {
    final profile = dependencies.profileViewModel;
    final path = state.uri.path;
    if (!profile.initialized) {
      return path == '/welcome' ? null : '/welcome';
    }
    if (profile.profile == null) {
      return path == '/welcome' ? null : '/welcome';
    }
    if (profile.needsOnboarding) {
      return path == '/onboarding' ? null : '/onboarding';
    }
    if (path == '/' || path == '/welcome' || path == '/onboarding') {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) =>
          WelcomeScreen(viewModel: dependencies.profileViewModel),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) =>
          OnboardingScreen(viewModel: dependencies.profileViewModel),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          LearnerShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => HomeScreen(
                profileViewModel: dependencies.profileViewModel,
                insightsViewModel: dependencies.insightsViewModel,
              ),
              routes: [
                GoRoute(
                  path: 'advanced',
                  builder: (context, state) =>
                      const AdvancedLearningHubScreen(),
                  routes: [
                    GoRoute(
                      path: 'practice',
                      builder: (context, state) => AdvancedPracticeScreen(
                        viewModel: dependencies.p1ViewModel,
                      ),
                    ),
                    GoRoute(
                      path: 'placement',
                      builder: (context, state) =>
                          PlacementScreen(viewModel: dependencies.p1ViewModel),
                    ),
                    GoRoute(
                      path: 'engagement',
                      builder: (context, state) =>
                          EngagementScreen(viewModel: dependencies.p1ViewModel),
                    ),
                    GoRoute(
                      path: 'premium',
                      builder: (context, state) =>
                          PremiumScreen(viewModel: dependencies.p1ViewModel),
                    ),
                    GoRoute(
                      path: 'support',
                      builder: (context, state) =>
                          SupportScreen(viewModel: dependencies.p1ViewModel),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/learn',
              name: 'learning',
              builder: (context, state) =>
                  LearningFlowScreen(viewModel: dependencies.learningViewModel),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/review',
              name: 'review',
              builder: (context, state) =>
                  ReviewScreen(viewModel: dependencies.insightsViewModel),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) =>
                  ProfileScreen(viewModel: dependencies.profileViewModel),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: SafeArea(
        child: Center(child: Text(strings.destinationUnavailable)),
      ),
    );
  },
);
