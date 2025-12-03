import 'package:flutter/material.dart';
import 'package:pai_app/core/constants/app_constants.dart';
import 'package:pai_app/core/theme/app_theme.dart';
import 'package:pai_app/presentation/pages/splash/splash_page.dart';

void main() {
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
      home: const SplashPage(),
    );
  }
}
