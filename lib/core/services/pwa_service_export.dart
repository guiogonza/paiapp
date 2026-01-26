// Exportación condicional que selecciona la implementación correcta
// según la plataforma (web o nativa)
export 'pwa_service_stub.dart'
    if (dart.library.html) 'pwa_service.dart';
