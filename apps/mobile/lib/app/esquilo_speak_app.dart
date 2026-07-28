import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import '../features/learning/data/learning_api_service.dart';
import '../features/learning/data/remote_learning_repository.dart';
import '../features/learning/presentation/learning_flow_screen.dart';
import '../features/learning/presentation/learning_view_model.dart';
import '../l10n/app_localizations.dart';

class EsquiloSpeakApp extends StatefulWidget {
  const EsquiloSpeakApp({super.key});

  @override
  State<EsquiloSpeakApp> createState() => _EsquiloSpeakAppState();
}

class _EsquiloSpeakAppState extends State<EsquiloSpeakApp> {
  late final http.Client _httpClient;
  late final LearningViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    const configuredBaseUrl = String.fromEnvironment('ESQUILO_API_URL');
    final baseUrl = configuredBaseUrl.isNotEmpty
        ? configuredBaseUrl
        : defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
    _viewModel = LearningViewModel(
      RemoteLearningRepository(
        LearningApiService(_httpClient, Uri.parse(baseUrl)),
      ),
    )..loadCatalog();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D6B52),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: LearningFlowScreen(viewModel: _viewModel),
    );
  }
}
