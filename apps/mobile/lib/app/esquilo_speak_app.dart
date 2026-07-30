import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/app_theme.dart';
import '../core/navigation/app_router.dart';
import '../l10n/app_localizations.dart';
import 'app_dependencies.dart';

class EsquiloSpeakApp extends StatefulWidget {
  const EsquiloSpeakApp({this.dependencies, super.key});

  final AppDependencies? dependencies;

  @override
  State<EsquiloSpeakApp> createState() => _EsquiloSpeakAppState();
}

class _EsquiloSpeakAppState extends State<EsquiloSpeakApp> {
  AppDependencies? _dependencies;
  GoRouter? _router;
  Object? _bootstrapError;
  late final bool _ownsDependencies;

  @override
  void initState() {
    super.initState();
    _ownsDependencies = widget.dependencies == null;
    final dependencies = widget.dependencies;
    if (dependencies == null) {
      _initialize();
    } else {
      _setDependencies(dependencies);
    }
  }

  Future<void> _initialize() async {
    try {
      final dependencies = await AppDependencies.create();
      if (!mounted) {
        await dependencies.dispose();
        return;
      }
      setState(() => _setDependencies(dependencies));
    } on Object catch (error, stackTrace) {
      assert(() {
        debugPrint('EsquiloSpeak bootstrap failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      if (mounted) setState(() => _bootstrapError = error);
    }
  }

  void _setDependencies(AppDependencies dependencies) {
    _dependencies = dependencies;
    _router = createAppRouter(dependencies);
  }

  @override
  void dispose() {
    _router?.dispose();
    if (_ownsDependencies) _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) return _bootstrapApp();
    return MaterialApp.router(
      routerConfig: router,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
    );
  }

  Widget _bootstrapApp() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: _bootstrapError == null
              ? Semantics(
                  liveRegion: true,
                  label: 'Loading EsquiloSpeak',
                  child: const CircularProgressIndicator(),
                )
              : const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'EsquiloSpeak could not start. Check the environment '
                    'configuration and try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    ),
  );
}
