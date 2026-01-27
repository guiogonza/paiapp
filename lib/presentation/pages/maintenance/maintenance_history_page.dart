import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/core/constants/maintenance_rules.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

class MaintenanceHistoryPage extends StatefulWidget {
  final String? vehicleId;

  const MaintenanceHistoryPage({super.key, this.vehicleId});

  @override
  State<MaintenanceHistoryPage> createState() => _MaintenanceHistoryPageState();
}

class _MaintenanceHistoryPageState extends State<MaintenanceHistoryPage> {
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  final _gpsAuthService = GPSAuthService();

  List<MaintenanceEntity> _allMaintenanceList = [];
  List<MaintenanceEntity> _filteredMaintenanceList = [];
  List<VehicleEntity> _vehicles = [];
  VehicleEntity? _selectedVehicle;
  String? _selectedServiceType; // Filtro por tipo de servicio
  bool _isLoading = true;

  // Tipos de mantenimiento disponibles
  final List<String> _serviceTypes = [
    'Todos',
    ...MaintenanceRules.standardTypes,
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _selectedServiceType = 'Todos'; // Por defecto mostrar todos
    _loadVehicles();
    if (widget.vehicleId != null) {
      _loadHistory(widget.vehicleId!);
    } else {
      _loadAllHistory();
    }
  }

  Future<void> _loadVehicles() async {
    // 1) Intentar obtener vehículos locales
    final result = await _vehicleRepository.getVehicles();
    List<VehicleEntity> localVehicles = [];

    result.fold(
      (failure) {
        // Ignorar errores locales
      },
      (vehicles) {
        localVehicles = vehicles;
      },
    );

    // 2) Si no hay vehículos locales, cargar desde GPS
    List<VehicleEntity> vehiclesToUse = localVehicles;
    if (vehiclesToUse.isEmpty) {
      try {
        final gpsDevices = await _gpsAuthService.getDevicesFromGPS();
        vehiclesToUse = gpsDevices.map((device) {
          return VehicleEntity(
            id: device['id']?.toString() ?? '',
            placa:
                device['name']?.toString() ??
                device['label']?.toString() ??
                device['plate']?.toString() ??
                'Sin placa',
            marca: 'GPS',
            modelo: 'Sincronizado',
            ano: DateTime.now().year,
            gpsDeviceId: device['id']?.toString(),
          );
        }).toList();
        debugPrint(
          '🛰️ Vehículos cargados desde GPS (mantenimiento): ${vehiclesToUse.length}',
        );
      } catch (e) {
        debugPrint('❌ Error cargando vehículos desde GPS: $e');
      }
    }

    if (mounted) {
      setState(() {
        _vehicles = vehiclesToUse;
        if (_vehicles.isNotEmpty && widget.vehicleId != null) {
          _selectedVehicle = _vehicles.firstWhere(
            (v) => v.id == widget.vehicleId,
            orElse: () => _vehicles.first,
          );
        }
      });
    }
  }

  Future<void> _loadHistory(String vehicleId) async {
    setState(() {
      _isLoading = true;
    });

    final result = await _maintenanceRepository.getHistory(vehicleId);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar historial: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      },
      (maintenanceList) {
        if (mounted) {
          setState(() {
            _allMaintenanceList = maintenanceList;
            _applyFilters();
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _loadAllHistory() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _maintenanceRepository.getAllMaintenance();

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar historial: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      },
      (maintenanceList) {
        if (mounted) {
          setState(() {
            _allMaintenanceList = maintenanceList;
            _applyFilters();
            _isLoading = false;
          });
        }
      },
    );
  }

  void _applyFilters() {
    List<MaintenanceEntity> filtered = List.from(_allMaintenanceList);

    // Filtrar por vehículo
    if (_selectedVehicle != null) {
      filtered = filtered
          .where((m) => m.vehicleId == _selectedVehicle!.id)
          .toList();
    }

    // Filtrar por tipo de servicio
    if (_selectedServiceType != null && _selectedServiceType != 'Todos') {
      filtered = filtered
          .where((m) => m.serviceType == _selectedServiceType)
          .toList();
    }

    setState(() {
      _filteredMaintenanceList = filtered;
    });
  }

  Future<void> _exportToExcel() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La exportación a Excel solo está disponible en web'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_filteredMaintenanceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Crear un nuevo libro de Excel
      final excel = Excel.createExcel();

      // Renombrar Sheet1 a Mantenimiento
      excel.rename('Sheet1', 'Mantenimiento');
      final sheet = excel['Mantenimiento'];

      // Formato de fecha
      final dateFormat = DateFormat('dd/MM/yyyy');
      final numberFormat = NumberFormat('#,##0');

      // Crear mapa de vehículos para mostrar placas
      final vehiclesMap = <String, String>{};
      for (var vehicle in _vehicles) {
        if (vehicle.id != null) {
          vehiclesMap[vehicle.id!] = vehicle.placa;
        }
      }

      // Título
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('Historial de Mantenimiento');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Encabezados
      final headers = [
        'Fecha',
        'Vehículo',
        'Tipo de Servicio',
        'Servicio Personalizado',
        'Kilometraje',
        'Costo',
        'Proveedor',
      ];

      int startRow = 3;
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Datos
      for (int i = 0; i < _filteredMaintenanceList.length; i++) {
        final maintenance = _filteredMaintenanceList[i];
        final rowIndex = startRow + 1 + i;

        // Fecha
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          dateFormat.format(maintenance.serviceDate),
        );

        // Vehículo
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          vehiclesMap[maintenance.vehicleId] ?? maintenance.vehicleId,
        );

        // Tipo de Servicio
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          maintenance.serviceType,
        );

        // Servicio Personalizado
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          maintenance.customServiceName ?? '-',
        );

        // Kilometraje
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          numberFormat.format(maintenance.kmAtService.toInt()),
        );

        // Costo
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = IntCellValue(
          maintenance.cost.toInt(),
        );

        // Proveedor
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          maintenance.providerName ?? '-',
        );
      }

      // Ajustar ancho de columnas
      sheet.setColumnWidth(0, 12); // Fecha
      sheet.setColumnWidth(1, 15); // Vehículo
      sheet.setColumnWidth(2, 18); // Tipo de Servicio
      sheet.setColumnWidth(3, 25); // Servicio Personalizado
      sheet.setColumnWidth(4, 15); // Kilometraje
      sheet.setColumnWidth(5, 12); // Costo
      sheet.setColumnWidth(6, 20); // Proveedor

      // Totales
      final totalRow = startRow + 1 + _filteredMaintenanceList.length;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow))
          .value = TextCellValue(
        'TOTAL',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow))
          .cellStyle = CellStyle(
        bold: true,
      );

      final totalCost = _filteredMaintenanceList.fold<double>(
        0,
        (sum, m) => sum + m.cost,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRow))
          .value = IntCellValue(
        totalCost.toInt(),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRow))
          .cellStyle = CellStyle(
        bold: true,
      );

      // Convertir a bytes
      final excelBytes = excel.save();
      if (excelBytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      // Descargar en web
      final blob = html.Blob([excelBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'historial_mantenimiento.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exportación completada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Mantenimiento'),
        actions: [
          if (_filteredMaintenanceList.isNotEmpty && kIsWeb)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.orange),
              onPressed: _exportToExcel,
              tooltip: 'Exportar a Excel',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Filtro por vehículo
                DropdownButtonFormField<VehicleEntity>(
                  initialValue: _selectedVehicle,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Vehículo',
                    prefixIcon: const Icon(Icons.directions_car),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Opcional: Selecciona un vehículo',
                  ),
                  items: [
                    const DropdownMenuItem<VehicleEntity>(
                      value: null,
                      child: Text('Todos los vehículos'),
                    ),
                    ..._vehicles.map((vehicle) {
                      return DropdownMenuItem(
                        value: vehicle,
                        child: Text(vehicle.placa),
                      );
                    }),
                  ],
                  onChanged: (vehicle) {
                    setState(() {
                      _selectedVehicle = vehicle;
                    });
                    if (vehicle == null) {
                      _loadAllHistory();
                    } else {
                      _loadHistory(vehicle.id!);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Filtro por tipo de servicio
                DropdownButtonFormField<String>(
                  initialValue: _selectedServiceType,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Tipo de Servicio',
                    prefixIcon: const Icon(Icons.build),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _serviceTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (type) {
                    setState(() {
                      _selectedServiceType = type;
                    });
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),

          // Lista de mantenimientos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMaintenanceList.isEmpty
                ? const Center(child: Text('No hay registros de mantenimiento'))
                : ListView.builder(
                    itemCount: _filteredMaintenanceList.length,
                    padding: const EdgeInsets.all(16.0),
                    itemBuilder: (context, index) {
                      final maintenance = _filteredMaintenanceList[index];
                      final vehiclePlate = _vehicles
                          .firstWhere(
                            (v) => v.id == maintenance.vehicleId,
                            orElse: () => VehicleEntity(
                              id: maintenance.vehicleId,
                              placa: maintenance.vehicleId,
                              marca: '',
                              modelo: '',
                              ano: 0,
                            ),
                          )
                          .placa;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              maintenance.serviceType[0],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            maintenance.serviceType,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vehículo: $vehiclePlate'),
                              Text(
                                'Fecha: ${DateFormat('dd/MM/yyyy').format(maintenance.serviceDate)}',
                              ),
                              Text(
                                'Kilometraje: ${NumberFormat('#,##0').format(maintenance.kmAtService)} km',
                              ),
                              Text(
                                'Costo: \$${NumberFormat('#,##0.00').format(maintenance.cost)}',
                              ),
                              if (maintenance.customServiceName != null &&
                                  maintenance.customServiceName!.isNotEmpty)
                                Text(
                                  'Servicio: ${maintenance.customServiceName}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
