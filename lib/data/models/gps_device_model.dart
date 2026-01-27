/// Modelo que representa un dispositivo GPS tal como viene del API
/// https://plataforma.sistemagps.online/api/get_devices
class GPSDeviceModel {
  final String id;
  final String name;
  final String? label;
  final String? plate;
  final String? imei;
  final double? lat;
  final double? lng;
  final int? speed;
  final String? status;
  final DateTime? lastUpdate;

  GPSDeviceModel({
    required this.id,
    required this.name,
    this.label,
    this.plate,
    this.imei,
    this.lat,
    this.lng,
    this.speed,
    this.status,
    this.lastUpdate,
  });

  /// Crea un GPSDeviceModel desde el JSON del API
  factory GPSDeviceModel.fromJson(Map<String, dynamic> json) {
    return GPSDeviceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString(),
      plate: json['plate']?.toString(),
      imei: json['imei']?.toString(),
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng']),
      speed: _parseInt(json['speed']),
      status: json['status']?.toString(),
      lastUpdate: _parseDateTime(json['last_update'] ?? json['lastUpdate']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Obtiene la placa/identificador del vehículo
  /// Prioridad: name > label > plate > 'Sin placa'
  String get placa {
    if (name.isNotEmpty) return name;
    if (label != null && label!.isNotEmpty) return label!;
    if (plate != null && plate!.isNotEmpty) return plate!;
    return 'Sin placa';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'plate': plate,
      'imei': imei,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'status': status,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'GPSDeviceModel(id: $id, placa: $placa, lat: $lat, lng: $lng)';
  }
}
