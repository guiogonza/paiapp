import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pai_app/core/constants/app_constants.dart';
import 'package:pai_app/core/theme/app_theme.dart';
import 'package:pai_app/core/services/pwa_service_export.dart';
import 'package:pai_app/presentation/pages/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar servicio PWA para web
  if (kIsWeb) {
    await PWAService().initialize();
  }

  // Manejo global de errores de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
    // En web, también enviar al console.error de JavaScript
    if (kIsWeb) {
      // ignore: avoid_print
      print('ERROR_DETAILS: ${details.exception.toString()}');
    }
  };

  print('✅ App initialized (PostgreSQL mode - no Supabase)');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés
      ],
      locale: const Locale('es', 'ES'),
      home: const SplashPage(),
    );
  }
}
