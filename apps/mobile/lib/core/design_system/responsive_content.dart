import 'package:flutter/material.dart';

import 'app_tokens.dart';

enum AppWindowSize { compact, medium, expanded }

AppWindowSize windowSizeFor(double width) {
  if (width < AppBreakpoints.compact) return AppWindowSize.compact;
  if (width < AppBreakpoints.expanded) return AppWindowSize.medium;
  return AppWindowSize.expanded;
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = windowSizeFor(constraints.maxWidth);
      final maxWidth = switch (size) {
        AppWindowSize.compact => double.infinity,
        AppWindowSize.medium => 760.0,
        AppWindowSize.expanded => 920.0,
      };
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
    },
  );
}
