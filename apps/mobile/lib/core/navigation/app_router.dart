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
import '../../features/practice/presentation/practice_hub_screen.dart';
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
      builder: (context, state) => OnboardingScreen(
        viewModel: dependencies.profileViewModel,
        learningViewModel: dependencies.learningViewModel,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => LearnerShell(
        navigationShell: navigationShell,
        onBranchChanged: (previousIndex, nextIndex) async {
          if (previousIndex == 1 && nextIndex != 1) {
            await dependencies.dailySessionViewModel.abandonActiveSession();
          }
        },
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => HomeScreen(
                dailySessionViewModel: dependencies.dailySessionViewModel,
              ),
              routes: [
                GoRoute(
                  path: 'practice',
                  builder: (context, state) => PracticeHubScreen(
                    learning: dependencies.learningViewModel,
                    insights: dependencies.insightsViewModel,
                  ),
                ),
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
                      builder: (context, state) => PlacementScreen(
                        viewModel: dependencies.p1ViewModel,
                        learningViewModel: dependencies.learningViewModel,
                      ),
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
              builder: (context, state) => LearningFlowScreen(
                viewModel: dependencies.learningViewModel,
                onPlayMedia: dependencies.p1ViewModel.playMedia,
                onDownloadMedia: dependencies.p1ViewModel.downloadMedia,
              ),
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
              builder: (context, state) => ProfileScreen(
                viewModel: dependencies.profileViewModel,
                engagementViewModel: dependencies.p1ViewModel,
                languages: dependencies.learningViewModel.languages,
              ),
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
