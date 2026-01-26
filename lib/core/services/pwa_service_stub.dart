import 'dart:async';

/// Información del dispositivo y navegador (stub para plataformas no-web)
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

/// Servicio PWA stub para plataformas no-web
class PWAService {
  static final PWAService _instance = PWAService._internal();
  factory PWAService() => _instance;
  PWAService._internal();
  
  final _installStateController = StreamController<bool>.broadcast();
  Stream<bool> get installStateStream => _installStateController.stream;
  
  bool get canInstall => false;
  DeviceInfo? get deviceInfo => null;
  
  Future<void> initialize() async {
    // No hacer nada en plataformas no-web
  }
  
  Future<bool> promptInstall() async => false;
  
  String getInstallInstructions() => 'Esta función solo está disponible en la versión web.';
  
  void dispose() {
    _installStateController.close();
  }
}
