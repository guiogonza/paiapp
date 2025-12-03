import 'package:flutter/material.dart';
import 'package:pai_app/core/constants/app_constants.dart';
import 'package:pai_app/core/theme/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Navegar a la siguiente pantalla después del splash
    Future.delayed(
      const Duration(milliseconds: AppConstants.splashDuration),
      () {
        if (mounted) {
          // TODO: Navegar a la pantalla principal o de autenticación
          // Navigator.of(context).pushReplacementNamed('/home');
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navyBlue,
              AppColors.royalBlue,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo I°PAI
                      _buildLogo(),
                      const SizedBox(height: 24),
                      // Tagline
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          AppConstants.appTagline,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: AppColors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    // Logo de texto simple: "PAI"
    return Text(
      'PAI',
      style: TextStyle(
        fontSize: 72,
        fontWeight: FontWeight.bold,
        color: AppColors.orange,
        letterSpacing: 4,
        height: 1.0,
      ),
    );
  }

  Widget _buildLetter(String letter, Color color) {
    return Text(
      letter,
      style: TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0,
        height: 1.0,
      ),
    );
  }
}

