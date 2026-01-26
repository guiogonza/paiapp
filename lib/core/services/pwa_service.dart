import 'dart:async';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Información del dispositivo y navegador
class DeviceInfo {
  final String os;
  final String osVersion;
  final String browser;
  final String browserVersion;
  final bool isMobile;
  final bool isStandalone;
  final bool canInstall;

  DeviceInfo({
    required this.os,
    required this.osVersion,
    required this.browser,
    required this.browserVersion,
    required this.isMobile,
    required this.isStandalone,
    required this.canInstall,
  });

  @override
  String toString() {
    return 'DeviceInfo(os: $os $osVersion, browser: $browser $browserVersion, isMobile: $isMobile, isStandalone: $isStandalone, canInstall: $canInstall)';
  }
}

/// Servicio para manejar la funcionalidad PWA
class PWAService {
  static final PWAService _instance = PWAService._internal();
  factory PWAService() => _instance;
  PWAService._internal();

  // Stream controller para notificar cambios en el estado de instalación
  final _installStateController = StreamController<bool>.broadcast();
  Stream<bool> get installStateStream => _installStateController.stream;

  // Evento de instalación diferido
  dynamic _deferredPrompt;

  // Estado de instalación
  bool _canInstall = false;
  bool _hasPrompt = false;

  /// Retorna true si se puede mostrar la opción de instalar
  /// (no está en standalone y el navegador soporta PWA)
  bool get canInstall {
    if (_deviceInfo == null) return false;
    if (_deviceInfo!.isStandalone) return false;
    // Siempre permitir si el navegador soporta PWA (aunque no tengamos el prompt)
    return _deviceInfo!.canInstall;
  }

  /// Retorna true si tenemos el prompt nativo disponible
  bool get hasNativePrompt => _hasPrompt || _deferredPrompt != null;

  // Info del dispositivo
  DeviceInfo? _deviceInfo;
  DeviceInfo? get deviceInfo => _deviceInfo;

  /// Inicializar el servicio PWA
  Future<void> initialize() async {
    if (!kIsWeb) return;

    _deviceInfo = _detectDevice();
    print('📱 PWA Service initialized: $_deviceInfo');

    // Registrar el Service Worker
    await _registerServiceWorker();

    // Escuchar el evento beforeinstallprompt
    _listenForInstallPrompt();
  }

  /// Registrar el Service Worker
  Future<void> _registerServiceWorker() async {
    try {
      final navigator = html.window.navigator;
      final serviceWorker = js.context['navigator']['serviceWorker'];

      if (serviceWorker != null) {
        await html.window.navigator.serviceWorker?.register('/sw.js');
        print('✅ Service Worker registered');
      }
    } catch (e) {
      print('⚠️ Service Worker registration failed: $e');
    }
  }

  /// Escuchar el evento de instalación
  void _listenForInstallPrompt() {
    // Verificar si ya hay un prompt guardado en window
    _checkExistingPrompt();

    html.window.addEventListener('beforeinstallprompt', (event) {
      print('📲 beforeinstallprompt event fired');
      // Prevenir el prompt automático
      event.preventDefault();
      // Guardar el evento para usarlo después
      _deferredPrompt = event;
      _hasPrompt = true;
      _canInstall = true;

      // Guardar también en window para persistencia
      js.context['deferredPrompt'] = event;

      _installStateController.add(true);
    });

    // Escuchar cuando la app se instala
    html.window.addEventListener('appinstalled', (event) {
      print('✅ App was installed');
      _canInstall = false;
      _hasPrompt = false;
      _deferredPrompt = null;
      js.context['deferredPrompt'] = null;
      _installStateController.add(false);
    });
  }

  /// Detectar sistema operativo y navegador
  DeviceInfo _detectDevice() {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final platform = html.window.navigator.platform?.toLowerCase() ?? '';

    // Detectar SO
    String os = 'Unknown';
    String osVersion = '';
    bool isMobile = false;

    if (userAgent.contains('android')) {
      os = 'Android';
      isMobile = true;
      final match = RegExp(r'android (\d+\.?\d*)').firstMatch(userAgent);
      osVersion = match?.group(1) ?? '';
    } else if (userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod')) {
      os = 'iOS';
      isMobile = true;
      final match = RegExp(r'os (\d+[_\.]\d+)').firstMatch(userAgent);
      osVersion = match?.group(1)?.replaceAll('_', '.') ?? '';
    } else if (userAgent.contains('windows')) {
      os = 'Windows';
      if (userAgent.contains('windows nt 10')) {
        osVersion = '10/11';
      } else if (userAgent.contains('windows nt 6.3'))
        osVersion = '8.1';
      else if (userAgent.contains('windows nt 6.2'))
        osVersion = '8';
      else if (userAgent.contains('windows nt 6.1'))
        osVersion = '7';
    } else if (userAgent.contains('mac os')) {
      os = 'macOS';
      final match = RegExp(r'mac os x (\d+[_\.]\d+)').firstMatch(userAgent);
      osVersion = match?.group(1)?.replaceAll('_', '.') ?? '';
    } else if (userAgent.contains('linux')) {
      os = 'Linux';
    } else if (userAgent.contains('cros')) {
      os = 'Chrome OS';
    }

    // Detectar navegador
    String browser = 'Unknown';
    String browserVersion = '';

    if (userAgent.contains('edg/')) {
      browser = 'Edge';
      final match = RegExp(r'edg/(\d+\.?\d*)').firstMatch(userAgent);
      browserVersion = match?.group(1) ?? '';
    } else if (userAgent.contains('opr/') || userAgent.contains('opera')) {
      browser = 'Opera';
      final match = RegExp(r'opr/(\d+\.?\d*)').firstMatch(userAgent);
      browserVersion = match?.group(1) ?? '';
    } else if (userAgent.contains('chrome') &&
        !userAgent.contains('chromium')) {
      browser = 'Chrome';
      final match = RegExp(r'chrome/(\d+\.?\d*)').firstMatch(userAgent);
      browserVersion = match?.group(1) ?? '';
    } else if (userAgent.contains('safari') && !userAgent.contains('chrome')) {
      browser = 'Safari';
      final match = RegExp(r'version/(\d+\.?\d*)').firstMatch(userAgent);
      browserVersion = match?.group(1) ?? '';
    } else if (userAgent.contains('firefox')) {
      browser = 'Firefox';
      final match = RegExp(r'firefox/(\d+\.?\d*)').firstMatch(userAgent);
      browserVersion = match?.group(1) ?? '';
    } else if (userAgent.contains('samsung')) {
      browser = 'Samsung Internet';
      final match = RegExp(r'samsungbrowser/(\d+\.?\d*)').firstMatch(userAgent);
      browserVersion = match?.group(1) ?? '';
    }

    // Verificar si está en modo standalone (instalado)
    final isStandalone = _checkStandalone();

    // Determinar si puede instalar
    final canInstall = _checkCanInstall(os, browser, isStandalone);

    return DeviceInfo(
      os: os,
      osVersion: osVersion,
      browser: browser,
      browserVersion: browserVersion,
      isMobile: isMobile,
      isStandalone: isStandalone,
      canInstall: canInstall,
    );
  }

  /// Verificar si la app está en modo standalone
  bool _checkStandalone() {
    try {
      // Para iOS
      final standalone = js.context['navigator']['standalone'];
      if (standalone == true) return true;

      // Para otros navegadores
      final matchMedia = html.window.matchMedia('(display-mode: standalone)');
      return matchMedia.matches;
    } catch (e) {
      return false;
    }
  }

  /// Verificar si el navegador soporta instalación PWA
  bool _checkCanInstall(String os, String browser, bool isStandalone) {
    if (isStandalone) return false; // Ya está instalado

    // Chrome, Edge, Opera, Samsung Internet soportan instalación nativa
    if (['Chrome', 'Edge', 'Opera', 'Samsung Internet'].contains(browser)) {
      return true;
    }

    // Safari en iOS soporta "Add to Home Screen"
    if (os == 'iOS' && browser == 'Safari') {
      return true;
    }

    // Firefox en Android tiene soporte limitado
    if (os == 'Android' && browser == 'Firefox') {
      return true;
    }

    return false;
  }

  /// Mostrar el prompt de instalación
  Future<bool> promptInstall() async {
    if (!kIsWeb) return false;

    final info = _deviceInfo;
    if (info == null) return false;

    // Si es iOS Safari, mostrar instrucciones manuales
    if (info.os == 'iOS' && info.browser == 'Safari') {
      return false; // Retornar false para mostrar instrucciones manuales
    }

    // Verificar si hay un prompt disponible en JavaScript
    final hasDeferredPrompt =
        js.context.callMethod('eval', [
              'window.deferredPrompt !== null && window.deferredPrompt !== undefined',
            ])
            as bool? ??
        false;

    // Para navegadores con soporte nativo
    if (hasDeferredPrompt || _deferredPrompt != null) {
      try {
        // Llamar a prompt() en el evento diferido guardado en window
        js.context.callMethod('eval', [
          '''
          (function() {
            if (window.deferredPrompt) {
              console.log('🚀 Calling prompt() on deferredPrompt');
              window.deferredPrompt.prompt();
              window.deferredPrompt.userChoice.then(function(choiceResult) {
                console.log('📱 User choice:', choiceResult.outcome);
                if (choiceResult.outcome === 'accepted') {
                  console.log('✅ User accepted the install prompt');
                } else {
                  console.log('❌ User dismissed the install prompt');
                }
                window.deferredPrompt = null;
              });
            } else {
              console.warn('⚠️ No deferredPrompt available');
            }
          })();
        ''',
        ]);

        _canInstall = false;
        _deferredPrompt = null;
        _installStateController.add(false);
        return true;
      } catch (e) {
        print('⚠️ Error prompting install: $e');
        return false;
      }
    }

    print('⚠️ No deferred prompt available');
    return false;
  }

  /// Obtener instrucciones de instalación según el dispositivo
  String getInstallInstructions() {
    final info = _deviceInfo;
    if (info == null) return 'No se puede determinar el dispositivo';

    if (info.isStandalone) {
      return '¡La app ya está instalada!';
    }

    switch (info.os) {
      case 'iOS':
        return '''Para instalar en ${info.os}:
1. Toca el botón de compartir (📤) en la barra inferior
2. Desplázate y toca "Añadir a pantalla de inicio"
3. Toca "Añadir" para confirmar''';

      case 'Android':
        if (info.browser == 'Chrome' || info.browser == 'Edge') {
          return '''Para instalar en ${info.os}:
1. Toca el menú (⋮) en la esquina superior
2. Selecciona "Instalar app" o "Añadir a pantalla de inicio"
3. Confirma la instalación''';
        } else if (info.browser == 'Samsung Internet') {
          return '''Para instalar en Samsung:
1. Toca el menú (≡) en la barra inferior
2. Selecciona "Añadir página a" > "Pantalla de inicio"
3. Confirma la instalación''';
        } else if (info.browser == 'Firefox') {
          return '''Para instalar en Firefox:
1. Toca el menú (⋮) 
2. Selecciona "Instalar"
3. Confirma la instalación''';
        }
        return '''Para instalar:
1. Abre el menú del navegador
2. Busca la opción "Instalar" o "Añadir a pantalla de inicio"''';

      case 'Windows':
      case 'macOS':
      case 'Linux':
      case 'Chrome OS':
        if (info.browser == 'Chrome') {
          return '''Para instalar en ${info.browser}:
1. Haz clic en el icono de instalación (⊕) en la barra de direcciones
2. O ve a Menú (⋮) > "Instalar PAI App"
3. Confirma la instalación''';
        } else if (info.browser == 'Edge') {
          return '''Para instalar en ${info.browser}:
1. Haz clic en el icono de instalación en la barra de direcciones
2. O ve a Menú (...) > "Aplicaciones" > "Instalar este sitio como aplicación"
3. Confirma la instalación''';
        }
        return '''Para instalar:
1. Busca el icono de instalación en la barra de direcciones
2. O accede desde el menú del navegador''';

      default:
        return 'Tu navegador puede no soportar la instalación de aplicaciones web.';
    }
  }

  /// Verificar si hay un prompt existente guardado en window
  void _checkExistingPrompt() {
    try {
      final hasDeferredPrompt =
          js.context.callMethod('eval', [
                'window.deferredPrompt !== null && window.deferredPrompt !== undefined',
              ])
              as bool? ??
          false;

      if (hasDeferredPrompt) {
        print('📲 Found existing deferredPrompt in window');
        _hasPrompt = true;
        _canInstall = true;
      }
    } catch (e) {
      print('⚠️ Error checking existing prompt: $e');
    }
  }

  /// Liberar recursos
  void dispose() {
    _installStateController.close();
  }
}
