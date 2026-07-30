import 'package:flutter/widgets.dart';

import 'app/app_dependencies.dart';
import 'app/esquilo_speak_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  runApp(EsquiloSpeakApp(dependencies: dependencies));
}
