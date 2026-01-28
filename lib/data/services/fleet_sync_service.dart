/// Servicio para sincronizar la flota desde el API de GPS a Supabase
/// DEPRECADO: Ya no se usa - funcionalidad migrada a GPSVehicleProvider
class FleetSyncService {
  /// Sincroniza los primeros 5 dispositivos del API de GPS a la base de datos
  /// DEPRECADO: Ya no se usa
  Future<Map<String, dynamic>> syncFleetLimited() async {
    throw UnimplementedError(
      'FleetSyncService ya no se usa - migrado a PostgreSQL',
    );
  }

  /// Sincroniza TODOS los dispositivos del API de GPS a la base de datos
  /// DEPRECADO: Ya no se usa
  Future<Map<String, dynamic>> syncFullFleet() async {
    throw UnimplementedError(
      'FleetSyncService ya no se usa - migrado a PostgreSQL',
    );
  }
}
