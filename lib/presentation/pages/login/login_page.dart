import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/core/services/local_auth_service.dart';
import 'package:pai_app/data/repositories/auth_repository_impl.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/presentation/pages/owner/owner_dashboard_page.dart';
import 'package:pai_app/presentation/pages/driver/driver_dashboard_page.dart';
import 'package:pai_app/presentation/widgets/pwa_install_prompt.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepositoryImpl();
  final _localAuthService = LocalAuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _hasSavedCredentials = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    // Cargar preferencia de "Recordarme"
    final rememberMe = await _localAuthService.getRememberMe();

    // Verificar si hay credenciales guardadas
    final savedCredentials = await _localAuthService.getSavedCredentials();

    // Verificar disponibilidad de biometría
    final biometricAvailable = await _localAuthService.isBiometricAvailable();
    final biometricEnabled = await _localAuthService.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        _hasSavedCredentials = savedCredentials != null;
        _biometricAvailable = biometricAvailable;
        _biometricEnabled = biometricEnabled;
      });

      // Si hay credenciales guardadas y recordarme está activo, cargarlas
      if (rememberMe && savedCredentials != null) {
        _usernameController.text = savedCredentials['username'] ?? '';
        _passwordController.text = savedCredentials['password'] ?? '';
      }

      // Si la biometría está habilitada y hay credenciales, ofrecer login biométrico
      if (biometricEnabled && _hasSavedCredentials && biometricAvailable) {
        _attemptBiometricLogin();
      }
    }
  }

  Future<void> _attemptBiometricLogin() async {
    final authenticated = await _localAuthService.authenticateWithBiometrics();
    if (authenticated) {
      final credentials = await _localAuthService.getSavedCredentials();
      if (credentials != null && mounted) {
        _usernameController.text = credentials['username'] ?? '';
        _passwordController.text = credentials['password'] ?? '';
        await _handleLogin();
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Construye el logo PPAI con imagen corporativa (tamaño compacto)
  Widget _buildPpaiLogo() {
    return Image.asset(
      'assets/images/ppai_logo.png',
      height: 160,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Si la imagen no existe, mostrar mensaje de ayuda
        debugPrint('Error cargando logo: $error');
        return const SizedBox(
          height: 160,
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔐 Intentando login con API local (PostgreSQL)...');
      print('   Usuario: ${_usernameController.text.trim()}');

      await _authRepository.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      print('✅ Login exitoso en API local');

      // SIEMPRE guardar credenciales para poder cargar vehículos del GPS
      await _localAuthService.saveCredentials(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Guardar credenciales GPS (las mismas que se usan para el login PAI)
      // Esto permite que los servicios de GPS puedan obtener ubicaciones de vehículos
      final gpsAuthService = GPSAuthService();
      print(
        '💾 Guardando credenciales GPS para: ${_usernameController.text.trim()}',
      );
      // Guardar las credenciales del usuario para GPS
      await gpsAuthService.saveGpsCredentialsLocally(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      print('✅ Credenciales GPS guardadas localmente');

      // Configurar preferencias de "Recordarme" y biometría
      if (_rememberMe) {
        await _localAuthService.setRememberMe(true);
      } else {
        await _localAuthService.setRememberMe(false);
        await _localAuthService.setBiometricEnabled(false);
      }

      if (mounted) {
        // Si el login fue exitoso y la biometría está disponible, preguntar si quiere habilitarla
        if (_biometricAvailable && _rememberMe && !_biometricEnabled) {
          _showBiometricPrompt();
        }
        _navigateToDashboard();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');

        // Mensajes más amigables para errores comunes
        if (errorMessage.contains('ERR_NAME_NOT_RESOLVED') ||
            errorMessage.contains('Failed to load resource') ||
            errorMessage.contains('network') ||
            errorMessage.contains('connection')) {
          errorMessage =
              'Error de conexión. Verifica tu internet y que puedas acceder a Supabase.';
        } else if (errorMessage.contains('Invalid login credentials') ||
            errorMessage.contains('Credenciales inválidas')) {
          errorMessage =
              'Usuario o contraseña incorrectos. Verifica tus credenciales.';
        } else if (errorMessage.contains('User not found')) {
          errorMessage =
              'Usuario no encontrado. Verifica tu usuario o regístrate primero.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showBiometricPrompt() {
    // Mostrar diálogo preguntando si quiere habilitar biometría
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Acceso Rápido'),
            ],
          ),
          content: const Text(
            '¿Deseas usar tu huella dactilar o Face ID para iniciar sesión más rápido la próxima vez?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('No, gracias'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _localAuthService.setBiometricEnabled(true);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Acceso biométrico habilitado!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Sí, habilitar'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _navigateToDashboard() async {
    try {
      final profileRepository = ProfileRepositoryImpl();
      final profileResult = await profileRepository.getCurrentUserProfile();

      if (mounted) {
        profileResult.fold(
          (failure) {
            // Si no se puede obtener el perfil, mostrar OwnerDashboardPage por defecto
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OwnerDashboardPage()),
            );
          },
          (profile) {
            // Redirigir según el role
            Widget targetPage;
            if (profile.role == 'owner' || profile.role == 'super_admin') {
              // super_admin tiene acceso completo como owner
              targetPage = const OwnerDashboardPage();
            } else if (profile.role == 'driver') {
              targetPage = const DriverDashboardPage();
            } else {
              // Role desconocido, mostrar OwnerDashboardPage por defecto
              targetPage = const OwnerDashboardPage();
            }

            Navigator.of(
              context,
            ).pushReplacement(MaterialPageRoute(builder: (_) => targetPage));
          },
        );
      }
    } catch (e) {
      // Error al obtener perfil, mostrar OwnerDashboardPage por defecto
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OwnerDashboardPage()),
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.register(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Después del registro, intentar hacer login automáticamente
      try {
        await _authRepository.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        // Guardar credenciales GPS del usuario después del login exitoso
        final gpsAuthService = GPSAuthService();
        await gpsAuthService.saveGpsCredentialsLocally(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          _navigateToDashboard();
        }
      } catch (loginError) {
        // Si el login falla (por ejemplo, si requiere confirmación de email),
        // mostrar mensaje pero permitir que el usuario intente iniciar sesión manualmente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Registro exitoso. Por favor, inicia sesión con tus credenciales.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo PPAI
                  _buildPpaiLogo(),
                  const SizedBox(height: 8),
                  Text(
                    'TECNOLOGÍA A TU ALCANCE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Usuario Field
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: const Icon(Icons.person_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText:
                          'Puede ser cualquier texto (email, nombre, etc.)',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu usuario';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu contraseña';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Checkbox Recordarme
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _rememberMe = !_rememberMe;
                          });
                        },
                        child: const Text(
                          'Recordar mis datos',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Login Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'INGRESAR',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  // Botón de Biometría (solo si está disponible y habilitada)
                  if (_biometricAvailable &&
                      _biometricEnabled &&
                      _hasSavedCredentials) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _attemptBiometricLogin,
                      icon: const Icon(Icons.fingerprint, size: 28),
                      label: const Text('Ingresar con huella / Face ID'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Register Link
                  TextButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: '¿No tienes cuenta? '),
                          TextSpan(
                            text: 'Regístrate',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // PWA Install Button
                  if (kIsWeb) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () =>
                          PWAInstallPrompt.showInstallDialog(context),
                      icon: const Icon(Icons.install_mobile),
                      label: const Text('Instalar App'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.accent),
                        foregroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
