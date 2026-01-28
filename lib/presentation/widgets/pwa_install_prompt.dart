import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pai_app/core/services/pwa_service_export.dart';

/// Widget que muestra un banner o botón para instalar la PWA
class PWAInstallPrompt extends StatefulWidget {
  final Widget? child;
  final bool showAsDialog;
  final bool showAsBanner;

  const PWAInstallPrompt({
    super.key,
    this.child,
    this.showAsDialog = false,
    this.showAsBanner = true,
  });

  @override
  State<PWAInstallPrompt> createState() => _PWAInstallPromptState();

  /// Mostrar diálogo de instalación
  static Future<void> showInstallDialog(BuildContext context) async {
    if (!kIsWeb) return;

    final pwaService = PWAService();
    final deviceInfo = pwaService.deviceInfo;

    if (deviceInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _getOSIcon(deviceInfo.os),
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Instalar PAI App', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getBrowserIcon(deviceInfo.browser),
                    size: 24,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${deviceInfo.os} ${deviceInfo.osVersion} • ${deviceInfo.browser}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (deviceInfo.isStandalone)
              const _InstalledMessage()
            else
              Text(
                pwaService.getInstallInstructions(),
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          // Mostrar botón de instalar si no está instalada y tenemos prompt nativo
          if (!deviceInfo.isStandalone &&
              // pwaService.hasNativePrompt &&
              deviceInfo.os != 'iOS')
            ElevatedButton.icon(
              onPressed: () async {
                final installed = await pwaService.promptInstall();
                if (context.mounted) {
                  Navigator.pop(context);
                  if (installed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Gracias por instalar PAI App!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Instalar ahora'),
            ),
        ],
      ),
    );
  }

  static IconData _getOSIcon(String os) {
    switch (os) {
      case 'iOS':
        return Icons.phone_iphone;
      case 'Android':
        return Icons.android;
      case 'Windows':
        return Icons.desktop_windows;
      case 'macOS':
        return Icons.laptop_mac;
      case 'Linux':
        return Icons.computer;
      case 'Chrome OS':
        return Icons.laptop_chromebook;
      default:
        return Icons.devices;
    }
  }

  static IconData _getBrowserIcon(String browser) {
    switch (browser) {
      case 'Chrome':
        return Icons.public; // Chrome icon
      case 'Safari':
        return Icons.explore; // Safari-like icon
      case 'Firefox':
        return Icons.local_fire_department; // Firefox-like
      case 'Edge':
        return Icons.language;
      case 'Opera':
        return Icons.radio_button_checked;
      case 'Samsung Internet':
        return Icons.phone_android;
      default:
        return Icons.web;
    }
  }
}

class _PWAInstallPromptState extends State<PWAInstallPrompt> {
  final PWAService _pwaService = PWAService();
  bool _showBanner = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkInstallState();
  }

  void _checkInstallState() {
    if (!kIsWeb) return;

    final deviceInfo = _pwaService.deviceInfo;
    if (deviceInfo != null &&
        !deviceInfo.isStandalone &&
        deviceInfo.canInstall) {
      setState(() => _showBanner = true);
    }

    // Escuchar cambios en el estado de instalación
    _pwaService.installStateStream.listen((canInstall) {
      if (mounted) {
        setState(() => _showBanner = canInstall && !_dismissed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !widget.showAsBanner || !_showBanner || _dismissed) {
      return widget.child ?? const SizedBox.shrink();
    }

    final deviceInfo = _pwaService.deviceInfo;
    if (deviceInfo == null) return widget.child ?? const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.install_mobile,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Instala PAI App',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Acceso rápido desde tu ${deviceInfo.isMobile ? "pantalla de inicio" : "escritorio"}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (deviceInfo.os != 'iOS' && _pwaService.canInstall)
                    TextButton(
                      onPressed: () async {
                        final installed = await _pwaService.promptInstall();
                        if (!installed && mounted) {
                          PWAInstallPrompt.showInstallDialog(context);
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Instalar'),
                    )
                  else
                    TextButton(
                      onPressed: () =>
                          PWAInstallPrompt.showInstallDialog(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Ver cómo'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _dismissed = true;
                        _showBanner = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.child != null) Expanded(child: widget.child!),
      ],
    );
  }
}

/// Mensaje cuando la app ya está instalada
class _InstalledMessage extends StatelessWidget {
  const _InstalledMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡App instalada!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  'Estás usando PAI App en modo aplicación.',
                  style: TextStyle(color: Colors.green.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón flotante para mostrar opciones de instalación PWA
class PWAInstallFAB extends StatelessWidget {
  const PWAInstallFAB({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final pwaService = PWAService();
    final deviceInfo = pwaService.deviceInfo;

    if (deviceInfo == null || deviceInfo.isStandalone) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: () => PWAInstallPrompt.showInstallDialog(context),
      icon: const Icon(Icons.install_mobile),
      label: const Text('Instalar App'),
      backgroundColor: Theme.of(context).primaryColor,
    );
  }
}
