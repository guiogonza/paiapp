import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/core/constants/app_constants.dart';
import 'package:pai_app/core/theme/app_theme.dart';
import 'package:pai_app/presentation/pages/splash/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  try {
    await Supabase.initialize(
      url: 'https://urlbbkpuaiugputhnsqx.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVybGJia3B1YWl1Z3B1dGhuc3F4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3NzgyNzgsImV4cCI6MjA4MDM1NDI3OH0.ZgzrG48R8slTh3ZsXiCYeMHa3vrCca4TNJUP7O4slxQ',
    );
    print('✅ Supabase initialized successfully');
  } catch (e, stackTrace) {
    print('❌ Error initializing Supabase: $e');
    print('Stack trace: $stackTrace');
    // Continuar aunque falle Supabase para ver si el problema es otro
  }
  
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
