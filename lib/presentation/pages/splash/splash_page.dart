import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/core/constants/app_constants.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/presentation/pages/login/login_page.dart';
import 'package:pai_app/presentation/pages/owner/owner_dashboard_page.dart';
import 'package:pai_app/presentation/pages/driver/driver_dashboard_page.dart';

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

    // Verificar sesión y navegar después del splash
    Future.delayed(
      const Duration(milliseconds: AppConstants.splashDuration),
      () {
        if (mounted) {
          _navigateToNextScreen();
        }
      },
    );
  }

  Future<void> _navigateToNextScreen() async {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null) {
      // Hay sesión activa, obtener el perfil y redirigir según el role
      try {
        final profileRepository = ProfileRepositoryImpl();
        final profileResult = await profileRepository.getCurrentUserProfile();
        
        if (mounted) {
          profileResult.fold(
            (failure) {
              // Si no se puede obtener el perfil, mostrar OwnerDashboardPage por defecto
              // (asumiendo que el usuario es owner si no tiene perfil)
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se encontró perfil. Mostrando dashboard de dueño por defecto.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const OwnerDashboardPage()),
                );
              }
            },
            (profile) {
              // Redirigir según el role
              Widget targetPage;
              if (profile.role == 'owner') {
                targetPage = const OwnerDashboardPage();
              } else if (profile.role == 'driver') {
                targetPage = const DriverDashboardPage();
              } else {
                // Role desconocido, mostrar OwnerDashboardPage por defecto
                targetPage = const OwnerDashboardPage();
              }
              
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => targetPage),
              );
            },
          );
        }
      } catch (e) {
        // Error al obtener perfil, mostrar OwnerDashboardPage por defecto
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar perfil: ${e.toString()}. Mostrando dashboard por defecto.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OwnerDashboardPage()),
          );
        }
      }
    } else {
      // No hay sesión, ir al Login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
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

}

