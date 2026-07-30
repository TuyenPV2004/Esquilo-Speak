import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_dependencies.dart';
import '../../features/learning/presentation/learning_flow_screen.dart';

GoRouter createAppRouter(AppDependencies dependencies) => GoRouter(
  initialLocation: '/learn',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/learn'),
    GoRoute(
      path: '/learn',
      name: 'learning',
      builder: (context, state) =>
          LearningFlowScreen(viewModel: dependencies.learningViewModel),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('EsquiloSpeak')),
    body: const SafeArea(
      child: Center(child: Text('This destination is unavailable.')),
    ),
  ),
);
