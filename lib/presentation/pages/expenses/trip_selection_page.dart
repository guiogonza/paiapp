import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Import condicional para web
import 'dart:html' as html show AnchorElement;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/data/repositories/trip_repository_impl.dart';
import 'package:pai_app/data/repositories/expense_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/presentation/pages/expenses/expense_form_page.dart';

/// Página para seleccionar un viaje antes de crear un gasto
/// Filtra los viajes según el rol del usuario:
/// - Driver: Solo viajes asignados a él o sin asignar
/// - Owner: Todos los viajes
class TripSelectionPage extends StatefulWidget {
  const TripSelectionPage({super.key});

  @override
  State<TripSelectionPage> createState() => _TripSelectionPageState();
}

class _TripSelectionPageState extends State<TripSelectionPage> {
  final _tripRepository = TripRepositoryImpl();
  final _profileRepository = ProfileRepositoryImpl();
  final _expenseRepository = ExpenseRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  
  List<TripEntity> _trips = [];
  List<TripEntity> _filteredTrips = [];
  Map<String, List<ExpenseEntity>> _expensesByTrip = {}; // tripId -> expenses
  Map<String, Map<String, String>> _driverNamesByTrip = {}; // tripId -> {driverId: name}
  bool _isLoading = true;
  String? _userRole;
  String? _userEmail;
  Map<String, VehicleEntity> _vehiclesById = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfileAndTrips();
  }

  Future<void> _loadUserProfileAndTrips() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener perfil del usuario para determinar el rol
      final profileResult = await _profileRepository.getCurrentUserProfile();
      
      profileResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar perfil: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (profile) {
          _userRole = profile.role;
          _userEmail = Supabase.instance.client.auth.currentUser?.email;
        },
      );

      // Cargar todos los viajes
      final tripsResult = await _tripRepository.getTrips();
      
      tripsResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar viajes: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (trips) async {
          // Filtrar viajes según el rol
          if (_userRole == 'driver') {
            // Driver: Solo viajes asignados a él o sin asignar
            _trips = trips.where((trip) {
              final driverName = trip.driverName.toLowerCase().trim();
              final userEmailLower = _userEmail?.toLowerCase().trim() ?? '';
              return driverName.isEmpty || driverName == userEmailLower;
            }).toList();
          } else {
            // Owner: Todos los viajes
            _trips = trips;
          }
          
          _filteredTrips = _trips;

          // Cargar vehículos para mostrar placa
          await _loadVehicles();
          // Cargar gastos para cada viaje
          _loadExpensesForTrips(_filteredTrips);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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

  void _filterTrips(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTrips = _trips;
      } else {
        final queryLower = query.toLowerCase();
        _filteredTrips = _trips.where((trip) {
          return trip.origin.toLowerCase().contains(queryLower) ||
                 trip.destination.toLowerCase().contains(queryLower) ||
                 trip.clientName.toLowerCase().contains(queryLower) ||
                 trip.driverName.toLowerCase().contains(queryLower);
        }).toList();
      }
    });
  }

  Future<void> _loadExpensesForTrips(List<TripEntity> trips) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    
    for (final trip in trips) {
      if (trip.id == null) continue;
      
      try {
        final expensesResult = _userRole == 'driver' && currentUserId != null
            ? await _expenseRepository.getExpensesByTripIdAndDriver(trip.id!, currentUserId)
            : await _expenseRepository.getExpensesByTripId(trip.id!);
        
        expensesResult.fold(
          (failure) {
            // Ignorar errores, simplemente no mostrar gastos
          },
          (expenses) {
            if (mounted) {
              setState(() {
                _expensesByTrip[trip.id!] = expenses;
              });
              
              // Si es owner, cargar nombres de conductores
              if (_userRole == 'owner') {
                _loadDriverNamesForTrip(trip.id!, expenses);
              }
            }
          },
        );
      } catch (e) {
        // Ignorar errores
      }
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

  Future<void> _loadDriverNamesForTrip(String tripId, List<ExpenseEntity> expenses) async {
    final driverIds = expenses
        .where((e) => e.driverId != null)
        .map((e) => e.driverId!)
        .toSet();

    final driverNames = <String, String>{};

    // Obtener el driver_name del viaje (que contiene el email del conductor)
    String? tripDriverName;
    try {
      final trip = _trips.firstWhere((t) => t.id == tripId);
      tripDriverName = trip.driverName;
    } catch (e) {
      // Ignorar
    }

    for (final driverId in driverIds) {
      try {
        // Primero intentar obtener desde profiles
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('id', driverId)
            .maybeSingle();

        if (profileResponse != null) {
          final name = profileResponse['full_name'] as String?;
          if (name != null && name.isNotEmpty) {
            driverNames[driverId] = name;
            continue;
          }
        }

        // Si no hay nombre en profiles, usar el driver_name del viaje
        // Generalmente todos los gastos de un viaje son del mismo conductor asignado
        if (tripDriverName != null && tripDriverName.isNotEmpty) {
          driverNames[driverId] = tripDriverName;
          continue;
        }

        // Si el driverId es el usuario actual, usar su email
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId == driverId) {
          final currentUserEmail = Supabase.instance.client.auth.currentUser?.email;
          if (currentUserEmail != null) {
            driverNames[driverId] = currentUserEmail;
            continue;
          }
        }

        // Si nada funciona, usar un mensaje genérico
        driverNames[driverId] = 'Conductor del viaje';
      } catch (e) {
        // Si hay error, usar el driver_name del viaje o un fallback
        driverNames[driverId] = tripDriverName ?? 'Conductor del viaje';
      }
    }

    if (mounted) {
      setState(() {
        _driverNamesByTrip[tripId] = driverNames;
      });
    }
  }

  void _downloadReceiptImage(String imageUrl, String expenseType, DateTime expenseDate) {
    if (kIsWeb) {
      final dateStr = DateFormat('yyyy-MM-dd').format(expenseDate);
      final fileName = 'recibo_${expenseType}_$dateStr.jpg';
      html.AnchorElement(href: imageUrl)
        ..setAttribute('download', fileName)
        ..click();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descarga iniciada'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToExpenseForm(String tripId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseFormPage(tripId: tripId),
      ),
    ).then((_) {
      // Recargar gastos después de registrar uno nuevo
      _loadExpensesForTrips(_filteredTrips);
    });
  }

  String _buildVehicleLabel(String vehicleId) {
    final vehicle = _vehiclesById[vehicleId];
    if (vehicle == null) {
      return '-';
    }
    return vehicle.placa;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Viaje'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserProfileAndTrips,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por origen, destino, cliente o conductor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _filterTrips,
            ),
          ),
          
          // Indicador de filtro activo
          if (_userRole == 'driver')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.accent.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mostrando solo viajes asignados a ti o sin asignar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Lista de viajes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTrips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _trips.isEmpty
                                  ? 'No hay viajes disponibles'
                                  : 'No se encontraron viajes',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_trips.isEmpty && _userRole == 'driver')
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Los viajes aparecerán cuando te sean asignados',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUserProfileAndTrips,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTrips.length,
                          itemBuilder: (context, index) {
                            final trip = _filteredTrips[index];
                            return _buildTripCard(trip);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(TripEntity trip) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isAssigned = trip.driverName.isNotEmpty;
    final vehicleLabel = _buildVehicleLabel(trip.vehicleId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToExpenseForm(trip.id ?? ''),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ruta
              Row(
                children: [
                  Icon(Icons.route, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${trip.origin} → ${trip.destination}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Cliente
              if (trip.clientName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Cliente: ${trip.clientName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Conductor
              Row(
                children: [
                  Icon(
                    Icons.drive_eta,
                    size: 16,
                    color: isAssigned ? Colors.green : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAssigned
                          ? 'Conductor: ${trip.driverName}'
                          : 'Sin asignar',
                      style: TextStyle(
                        fontSize: 14,
                        color: isAssigned ? Colors.grey[700] : Colors.grey[500],
                        fontStyle: isAssigned ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Vehículo
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Vehículo: $vehicleLabel',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Fecha
              if (trip.startDate != null)
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(trip.startDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 12),
              
              // Gastos registrados
              if (_expensesByTrip.containsKey(trip.id) && _expensesByTrip[trip.id]!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.receipt_long, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Gastos registrados:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._expensesByTrip[trip.id]!.take(3).map((expense) {
                  String? driverName;
                  if (_userRole == 'owner' && expense.driverId != null) {
                    driverName = _driverNamesByTrip[trip.id!]?[expense.driverId] ?? 'Desconocido';
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: Colors.grey[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.type,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(expense.date),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (_userRole == 'owner' && driverName != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Conductor: $driverName',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(expense.amount),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    if (_userRole == 'owner' && expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.download, size: 16),
                                        onPressed: () => _downloadReceiptImage(
                                          expense.receiptUrl!,
                                          expense.type,
                                          expense.date,
                                        ),
                                        tooltip: 'Descargar recibo',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: AppColors.accent,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_expensesByTrip[trip.id]!.length > 3)
                  Text(
                    '... y ${_expensesByTrip[trip.id]!.length - 3} más',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(
                        _expensesByTrip[trip.id]!.fold<double>(
                          0.0,
                          (sum, expense) => sum + expense.amount,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              
              // Botón de acción
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToExpenseForm(trip.id ?? ''),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Registrar Gasto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

