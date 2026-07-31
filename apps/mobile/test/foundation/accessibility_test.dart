import 'package:esquilospeak_mobile/core/design_system/app_theme.dart';
import 'package:esquilospeak_mobile/core/design_system/component_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('foundation controls meet Android accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppMessageState(
            icon: Icons.cloud_off,
            message: 'The network is unavailable.',
            actionLabel: 'Retry',
            onAction: () {},
          ),
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('message state remains usable at 200 percent text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: AppMessageState(
              icon: Icons.info_outline,
              message: 'Your answer is saved and will sync when possible.',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('saved'), findsOneWidget);
  });
}
