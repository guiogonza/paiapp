import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/remittance_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/remittance_with_route_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

class BillingDashboardPage extends StatefulWidget {
  const BillingDashboardPage({super.key});

  @override
  State<BillingDashboardPage> createState() => _BillingDashboardPageState();
}

class _BillingDashboardPageState extends State<BillingDashboardPage> {
  final _remittanceRepository = RemittanceRepositoryImpl();
  List<RemittanceWithRouteEntity> _pendingRemittances = [];
  List<RemittanceWithRouteEntity> _filteredRemittances = [];
  bool _isLoading = true;
  final _vehicleRepository = VehicleRepositoryImpl();
  Map<String, VehicleEntity> _vehiclesById = {};
  
  // Controladores de búsqueda
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'Todos'; // 'Todos', 'Origen', 'Destino', 'Cliente', 'Conductor'
  String? _selectedDriverFilter; // Para filtro por conductor (dropdown)
  List<String> _availableDrivers = []; // Lista de conductores con historial
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _loadPendingRemittances();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingRemittances() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _remittanceRepository.getPendingRemittancesWithRoutes();

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar remisiones: ${failure.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          _pendingRemittances = [];
          _isLoading = false;
        });
      },
      (remittances) async {
        // Cargar vehículos una sola vez
        await _loadVehicles();
        setState(() {
          _pendingRemittances = remittances;
          _filteredRemittances = remittances;
          _isLoading = false;
        });
        // Obtener lista de conductores únicos de las remisiones
        _updateAvailableDrivers(remittances);
        _applySearch();
      },
    );
  }

  void _updateAvailableDrivers(List<RemittanceWithRouteEntity> remittances) {
    final driversSet = <String>{};
    for (var remittance in remittances) {
      final driverName = remittance.driverName;
      if (driverName != null && driverName.isNotEmpty) {
        driversSet.add(driverName);
      }
    }
    setState(() {
      _availableDrivers = driversSet.toList()..sort();
    });
  }

  void _applySearch() {
    List<RemittanceWithRouteEntity> filtered = List.from(_pendingRemittances);

    switch (_searchType) {
      case 'Origen':
        final query = _searchController.text.toLowerCase().trim();
        if (query.isNotEmpty) {
          filtered = filtered.where((remittance) => 
            remittance.startLocation.toLowerCase().contains(query)
          ).toList();
        }
        break;
      case 'Destino':
        final query = _searchController.text.toLowerCase().trim();
        if (query.isNotEmpty) {
          filtered = filtered.where((remittance) => 
            remittance.endLocation.toLowerCase().contains(query)
          ).toList();
        }
        break;
      case 'Cliente':
        final query = _searchController.text.toLowerCase().trim();
        if (query.isNotEmpty) {
          filtered = filtered.where((remittance) {
            final clientName = remittance.clientName ?? remittance.receiverName;
            return clientName.toLowerCase().contains(query);
          }).toList();
        }
        break;
      case 'Conductor':
        // Usar el dropdown seleccionado
        if (_selectedDriverFilter != null && _selectedDriverFilter!.isNotEmpty) {
          filtered = filtered.where((remittance) => 
            remittance.driverName == _selectedDriverFilter
          ).toList();
        }
        break;
      case 'Todos':
      default:
        final query = _searchController.text.toLowerCase().trim();
        if (query.isNotEmpty) {
          filtered = filtered.where((remittance) {
            final clientName = remittance.clientName ?? remittance.receiverName;
            return remittance.startLocation.toLowerCase().contains(query) ||
                   remittance.endLocation.toLowerCase().contains(query) ||
                   clientName.toLowerCase().contains(query) ||
                   (remittance.driverName?.toLowerCase().contains(query) ?? false);
          }).toList();
        }
        break;
    }

    setState(() {
      _filteredRemittances = filtered;
    });
  }

  String _getSearchHint() {
    switch (_searchType) {
      case 'Origen':
        return 'Buscar por origen...';
      case 'Destino':
        return 'Buscar por destino...';
      case 'Cliente':
        return 'Buscar por cliente...';
      case 'Conductor':
        return 'Buscar por conductor...';
      case 'Todos':
      default:
        return 'Buscar en origen, destino, cliente o conductor...';
    }
  }

  Future<void> _loadVehicles() async {
    final result = await _vehicleRepository.getVehicles();
    result.fold(
      (failure) {
        _vehiclesById = {};
      },
      (vehicles) {
        final map = <String, VehicleEntity>{};
        for (final vehicle in vehicles) {
          if (vehicle.id != null) {
            map[vehicle.id!] = vehicle;
          }
        }
        _vehiclesById = map;
      },
    );
  }

  Future<void> _markAsCollected(RemittanceWithRouteEntity remittance) async {
    if (remittance.id == null) return;

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cobro'),
        content: Text(
          '¿Estás seguro de que deseas marcar esta remisión como cobrada?\n\n'
          'Cliente: ${remittance.clientName?.isNotEmpty == true ? remittance.clientName! : remittance.receiverName}\n'
          'Viaje: ${remittance.startLocation} → ${remittance.endLocation}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mostrar loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _remittanceRepository.markAsCollected(remittance.id!);

    if (!mounted) return;
    Navigator.pop(context); // Cerrar loading

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al marcar como cobrado: ${failure.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Remisión marcada como cobrada exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Recargar la lista
        _loadPendingRemittances();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobranza y Facturación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingRemittances,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          if (!_isLoading && _pendingRemittances.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.background,
              child: Column(
                children: [
                  // Selector de tipo de búsqueda
                  DropdownButtonFormField<String>(
                    initialValue: _searchType,
                    decoration: InputDecoration(
                      labelText: 'Buscar por',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Todos los campos')),
                      DropdownMenuItem(value: 'Origen', child: Text('Origen')),
                      DropdownMenuItem(value: 'Destino', child: Text('Destino')),
                      DropdownMenuItem(value: 'Cliente', child: Text('Cliente')),
                      DropdownMenuItem(value: 'Conductor', child: Text('Conductor')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _searchType = value;
                          if (value != 'Conductor') {
                            _selectedDriverFilter = null;
                          }
                        });
                        _applySearch();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Campo de búsqueda o dropdown de conductores
                  _searchType == 'Conductor'
                      ? DropdownButtonFormField<String>(
                          initialValue: _selectedDriverFilter,
                          decoration: InputDecoration(
                            labelText: 'Seleccionar conductor',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos los conductores'),
                            ),
                            ..._availableDrivers.map((driver) {
                              return DropdownMenuItem(
                                value: driver,
                                child: Text(driver),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedDriverFilter = value;
                            });
                            _applySearch();
                          },
                        )
                      : TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: _getSearchHint(),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _applySearch();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (_) => _applySearch(),
                        ),
                ],
              ),
            ),
          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pendingRemittances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay remisiones pendientes',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Todas las remisiones han sido cobradas',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPendingRemittances,
                        child: _filteredRemittances.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No se encontraron remisiones',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredRemittances.length,
                                itemBuilder: (context, index) {
                                  final remittance = _filteredRemittances[index];
                                  return _buildRemittanceCard(remittance);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemittanceCard(RemittanceWithRouteEntity remittance) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final createdAt = remittance.createdAt;
    final dateStr = createdAt != null ? dateFormat.format(createdAt) : 'N/A';
    final timeStr = createdAt != null ? timeFormat.format(createdAt) : '';
    final vehicleLabel = _buildVehicleLabel(remittance.vehicleId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con indicador de documento
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // Priorizar clientName del route (trip) para facturación
                        remittance.clientName?.isNotEmpty == true
                            ? remittance.clientName!
                            : remittance.receiverName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                // Indicador de estado y documento
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Estado de la remisión
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(remittance.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(remittance.status),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(remittance.status),
                            size: 16,
                            color: _getStatusColor(remittance.status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusLabel(remittance.status),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _getStatusColor(remittance.status),
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Botones de ver y descargar remisión (si tiene documento)
                    if (remittance.hasDocument) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () => _viewRemittanceImage(remittance),
                        tooltip: 'Ver remisión',
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, size: 20),
                        onPressed: () => _downloadRemittanceImage(remittance),
                        tooltip: 'Descargar remisión',
                        color: AppColors.accent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Información del viaje
            Row(
              children: [
                const Icon(
                  Icons.route,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viaje',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${remittance.startLocation} → ${remittance.endLocation}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Vehículo
            Row(
              children: [
                const Icon(
                  Icons.directions_car,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vehículo: $vehicleLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Fecha
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fecha: $dateStr${timeStr.isNotEmpty ? ' a las $timeStr' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (remittance.driverName != null && remittance.driverName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Conductor: ${remittance.driverName}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            // Importe a cobrar
            if (remittance.revenueAmount != null && remittance.revenueAmount! > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 20,
                    color: AppColors.paiOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importe a cobrar',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${remittance.revenueAmount!.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.paiOrange,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Botón de acción (solo para pendiente_cobrar)
            if (remittance.status == 'pendiente_cobrar')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsCollected(remittance),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Marcar como Cobrado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendiente_completar':
        return Colors.orange;
      case 'pendiente_cobrar':
        return Colors.blue;
      case 'cobrado':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pendiente_completar':
        return Icons.pending;
      case 'pendiente_cobrar':
        return Icons.payment;
      case 'cobrado':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pendiente_completar':
        return 'Pendiente Completar';
      case 'pendiente_cobrar':
        return 'Pendiente Cobrar';
      case 'cobrado':
        return 'Cobrado';
      default:
        return status;
    }
  }

  void _viewRemittanceImage(RemittanceWithRouteEntity remittance) {
    if (remittance.receiptUrl == null || remittance.receiptUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay remisión adjunta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar imagen en diálogo
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                'Remisión - ${remittance.clientName ?? remittance.receiverName}',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  remittance.receiptUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Error al cargar la imagen'),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _downloadRemittanceImage(remittance);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Descargar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadRemittanceImage(RemittanceWithRouteEntity remittance) async {
    if (remittance.receiptUrl == null || remittance.receiptUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay remisión adjunta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (kIsWeb) {
      try {
        // Mostrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
                SizedBox(width: 16),
                Text('Descargando imagen...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );

        // Descargar la imagen usando http
        final response = await http.get(Uri.parse(remittance.receiptUrl!));
        if (response.statusCode == 200) {
          // Crear un Blob con los bytes
          final blob = html.Blob([response.bodyBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          
          // Crear un elemento anchor y descargar
          final dateStr = remittance.createdAt != null
              ? DateFormat('yyyy-MM-dd').format(remittance.createdAt!)
              : 'remision';
          final fileName = 'remision_${remittance.clientName ?? remittance.receiverName}_$dateStr.jpg';
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          
          // Limpiar la URL del objeto
          html.Url.revokeObjectUrl(url);
          
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Descarga completada'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw Exception('Error al descargar: ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al descargar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Para móvil, abrir la URL en el navegador
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abre: ${remittance.receiptUrl}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _buildVehicleLabel(String vehicleId) {
    final vehicle = _vehiclesById[vehicleId];
    if (vehicle == null) {
      return '-';
    }
    return vehicle.placa;
  }
}

