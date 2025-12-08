import 'package:pai_app/domain/entities/remittance_entity.dart';
import 'package:pai_app/domain/entities/route_entity.dart';

/// Entidad combinada que une Remittance con Route para facilitar la visualización
class RemittanceWithRouteEntity {
  final RemittanceEntity remittance;
  final RouteEntity route;

  const RemittanceWithRouteEntity({
    required this.remittance,
    required this.route,
  });

  String get receiverName => remittance.receiverName;
  String get status => remittance.status;
  String get startLocation => route.startLocation;
  String get endLocation => route.endLocation;
  String? get documentUrl => remittance.documentUrl;
  DateTime? get createdAt => remittance.createdAt;
  String? get id => remittance.id;
  String? get routeId => remittance.routeId;
  String? get driverName => route.driverName;
  String? get clientName => route.clientName;
  String get vehicleId => route.vehicleId;

  bool get isPending => remittance.isPending;
  bool get isCollected => remittance.isCollected;
  bool get hasDocument => documentUrl != null && documentUrl!.isNotEmpty;
}

