import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/data/services/fleet_sync_service.dart';
import 'package:pai_app/data/services/gps_auth_service.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

class DriversManagementPage extends StatefulWidget {
  const DriversManagementPage({super.key});

  @override
  State<DriversManagementPage> createState() => _DriversManagementPageState();
}

class _DriversManagementPageState extends State<DriversManagementPage> {
  final _profileRepository = ProfileRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  final _fleetSyncService = FleetSyncService();
  final _gpsAuthService = GPSAuthService();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  Map<String, String> _drivers = {}; // id -> email/name
  final Map<String, String?> _assignedVehicleByDriver =
      {}; // id -> vehicleId (nullable)
  List<VehicleEntity> _vehicles = [];
  bool _isLoading = true;
  bool _isLoadingVehicles = true;
  bool _isCreating = false;
  Timer? _rateLimitTimer;
  int _rateLimitSeconds = 0;
  String? _selectedVehicleIdForNewDriver;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadDrivers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _rateLimitTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    if (!mounted) return;

    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      // Cargar SIEMPRE directamente del GPS (es la fuente de verdad)
      print('📡 Cargando vehículos del API GPS...');
      final gpsDevices = await _gpsAuthService.getDevicesFromGPS();

      if (gpsDevices.isNotEmpty) {
        final gpsVehicles = gpsDevices.map((device) {
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

        print('✅ ${gpsVehicles.length} vehículos cargados del GPS:');
        for (var v in gpsVehicles) {
          print('   - ${v.placa} (ID: ${v.id})');
        }

        if (mounted) {
          setState(() {
            _vehicles = gpsVehicles;
            _isLoadingVehicles = false;
          });
        }
      } else {
        print('⚠️ El API GPS no devolvió dispositivos');
        if (mounted) {
          setState(() {
            _isLoadingVehicles = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error al cargar del GPS: $e');
      if (mounted) {
        setState(() {
          _isLoadingVehicles = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar vehículos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _profileRepository.getDriversList();
    result.fold(
      (failure) {
        print('❌ Error al cargar conductores: ${failure.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar conductores: ${failure.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      (driversMap) {
        print('✅ Conductores cargados: ${driversMap.length}');
        if (mounted) {
          setState(() {
            _drivers = driversMap;
          });
          if (driversMap.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No hay conductores registrados. Crea uno nuevo o verifica que los usuarios existentes tengan role="driver" en la base de datos.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      },
    );

    // Cargar asignación de vehículos para cada conductor
    final driversWithVehicleResult = await _profileRepository
        .getDriversWithAssignedVehicle();

    driversWithVehicleResult.fold(
      (failure) {
        print(
          '❌ Error al cargar vehículos asignados a conductores: ${failure.message}',
        );
      },
      (profiles) {
        if (mounted) {
          setState(() {
            _assignedVehicleByDriver.clear();
            for (final profile in profiles) {
              _assignedVehicleByDriver[profile.id] = profile.assignedVehicleId;
            }
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startRateLimitTimer(int seconds) {
    _rateLimitTimer?.cancel();
    setState(() {
      _rateLimitSeconds = seconds;
    });

    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_rateLimitSeconds > 0) {
            _rateLimitSeconds--;
          } else {
            timer.cancel();
            _rateLimitTimer = null;
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _getAssignedVehicleLabel(String driverId) {
    final vehicleId = _assignedVehicleByDriver[driverId];
    if (vehicleId == null || vehicleId.isEmpty) {
      return 'Vehículo asignado: -';
    }

    VehicleEntity? vehicle;
    for (final v in _vehicles) {
      if (v.id == vehicleId) {
        vehicle = v;
        break;
      }
    }

    if (vehicle == null) {
      return 'Vehículo asignado: -';
    }

    return 'Vehículo asignado: ${vehicle.placa}';
  }

  Future<void> _showAssignVehicleDialog(
    String driverId,
    String displayName,
  ) async {
    String? selectedVehicleId = _assignedVehicleByDriver[driverId] ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Asignar vehículo a\n$displayName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedVehicleId,
                    decoration: const InputDecoration(
                      labelText: 'Vehículo asignado',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Sin vehículo asignado'),
                      ),
                      ..._vehicles.map(
                        (vehicle) => DropdownMenuItem<String>(
                          value: vehicle.id,
                          child: Text(
                            '${vehicle.placa} - ${vehicle.marca} ${vehicle.modelo}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedVehicleId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(selectedVehicleId);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final normalizedVehicleId = (result.isEmpty)
        ? null
        : result; // '' → null (sin vehículo)

    // Validar que el vehículo no esté asignado ya a otro conductor
    if (normalizedVehicleId != null) {
      String? conflictingDriverId;
      _assignedVehicleByDriver.forEach((otherDriverId, vehicleId) {
        if (otherDriverId != driverId &&
            vehicleId == normalizedVehicleId &&
            conflictingDriverId == null) {
          conflictingDriverId = otherDriverId;
        }
      });

      if (conflictingDriverId != null) {
        final assignedDriverName =
            _drivers[conflictingDriverId!] ?? 'otro conductor';

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Vehículo ocupado'),
                ],
              ),
              content: Text(
                'El vehículo seleccionado ya está asignado a $assignedDriverName.\n\nDesasígnalo primero o elige otro vehículo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }

        return; // No continuar con la actualización en BD
      }
    }

    final updateResult = await _profileRepository.updateAssignedVehicle(
      driverId: driverId,
      vehicleId: normalizedVehicleId,
    );

    updateResult.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar vehículo: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (_) {
        if (mounted) {
          setState(() {
            _assignedVehicleByDriver[driverId] = normalizedVehicleId;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehículo asignado actualizado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  Future<bool> _handleCreateDriver() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedVehicleIdForNewDriver == null ||
        _selectedVehicleIdForNewDriver!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una opción de vehículo'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }

    // Determinar si es sin vehículo
    final sinVehiculo = _selectedVehicleIdForNewDriver == 'sin_vehiculo';
    final vehicleIdToAssign = sinVehiculo
        ? null
        : _selectedVehicleIdForNewDriver;

    // Validar si el vehículo ya está asignado a otro conductor (solo si tiene vehículo)
    if (!sinVehiculo) {
      final selectedVehicleId = _selectedVehicleIdForNewDriver!;
      String? conflictingDriverId;
      _assignedVehicleByDriver.forEach((driverId, vehicleId) {
        if (vehicleId == selectedVehicleId && conflictingDriverId == null) {
          conflictingDriverId = driverId;
        }
      });

      if (conflictingDriverId != null) {
        final assignedDriverName =
            _drivers[conflictingDriverId!] ?? 'otro conductor';
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Vehículo ocupado'),
                ],
              ),
              content: Text(
                'El vehículo seleccionado ya está asignado a $assignedDriverName.\n\nDesasígnalo primero o elige otro vehículo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
        return false;
      }
    }

    setState(() {
      _isCreating = true;
    });

    final result = await _profileRepository.createDriver(
      _usernameController.text.trim(),
      _passwordController.text,
      fullName: _fullNameController.text.trim().isEmpty
          ? null
          : _fullNameController.text.trim(),
      assignedVehicleId: vehicleIdToAssign,
    );

    bool success = false;
    result.fold(
      (failure) {
        if (mounted) {
          // Detectar rate limiting y extraer segundos
          final rateLimitMatch = RegExp(
            r'(\d+) segundos?',
          ).firstMatch(failure.message);
          if (rateLimitMatch != null) {
            final seconds = int.tryParse(rateLimitMatch.group(1) ?? '0') ?? 0;
            _startRateLimitTimer(seconds);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear conductor: ${failure.message}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: rateLimitMatch != null ? 8 : 4),
            ),
          );
        }
      },
      (profile) {
        success = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conductor creado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          // Recargar lista
          _loadDrivers();
        }
      },
    );

    if (mounted) {
      setState(() {
        _isCreating = false;
      });
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Conductores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrivers,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lista de conductores existentes
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Conductores Registrados (${_drivers.length})',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_drivers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay conductores registrados',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._drivers.entries.map((entry) {
                              final driverId = entry.key;
                              final displayName = entry.value;
                              final vehicleLabel = _getAssignedVehicleLabel(
                                driverId,
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    child: Text(
                                      displayName.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ID: ${driverId.substring(0, 8)}...',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        vehicleLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: AppColors.primary,
                                    ),
                                    tooltip: 'Cambiar vehículo asignado',
                                    onPressed: () {
                                      _showAssignVehicleDialog(
                                        driverId,
                                        displayName,
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Mostrar loading mientras carga vehículos
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );

          // Cargar vehículos directamente del GPS
          List<VehicleEntity> vehiculosParaModal = [];
          try {
            print('═══════════════════════════════════════════════');
            print('🚗 INICIANDO CARGA DE VEHÍCULOS PARA MODAL');
            print('═══════════════════════════════════════════════');
            
            print('📡 Llamando a _gpsAuthService.getDevicesFromGPS()...');
            final gpsDevices = await _gpsAuthService.getDevicesFromGPS();
            print('📦 Respuesta recibida: ${gpsDevices.length} dispositivos');
            print('📦 Tipo de respuesta: ${gpsDevices.runtimeType}');

            if (gpsDevices.isNotEmpty) {
              vehiculosParaModal = gpsDevices.map((device) {
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

              print(
                '✅ ${vehiculosParaModal.length} vehículos listos para el modal:',
              );
              for (var v in vehiculosParaModal) {
                print('   - ${v.placa} (ID: ${v.id})');
              }
            }
          } catch (e, stackTrace) {
            print('❌ Error cargando vehículos: $e');
            print('📍 Stack trace: $stackTrace');
          }
          
          print('═══════════════════════════════════════════════');
          print('📊 RESUMEN: ${vehiculosParaModal.length} vehículos para el modal');
          print('═══════════════════════════════════════════════');

          // Cerrar loading
          if (mounted) Navigator.of(context).pop();
          if (!mounted) return;

          if (vehiculosParaModal.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudieron cargar los vehículos del GPS. Verifica tu conexión.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }

          // Mostrar diálogo de creación con los vehículos cargados
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) =>
                _buildDriverFormSheet(loadedVehicles: vehiculosParaModal),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear Conductor'),
      ),
    );
  }

  Widget _buildDriverFormSheet({required List<VehicleEntity> loadedVehicles}) {
    // Usar los vehículos pasados como parámetro para evitar problemas de estado
    print('═══════════════════════════════════════════════');
    print('📱 CONSTRUYENDO MODAL DE CREAR CONDUCTOR');
    print('═══════════════════════════════════════════════');
    print('📊 Vehículos recibidos: ${loadedVehicles.length}');
    print('📊 Lista vacía: ${loadedVehicles.isEmpty}');
    if (loadedVehicles.isNotEmpty) {
      print('📋 Lista de vehículos:');
      for (var v in loadedVehicles) {
        print('   ✓ Placa: ${v.placa}, ID: ${v.id}, GPS ID: ${v.gpsDeviceId}');
      }
    } else {
      print('⚠️ NO HAY VEHÍCULOS - El dropdown estará vacío!');
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Crear Nuevo Conductor',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Nombre completo (opcional)
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo (Opcional)',
                    hintText: 'Este campo es completamente opcional',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Vehículo asignado (OPCIONAL)
                Builder(
                  builder: (context) {
                    print('🔧 Construyendo DropdownButtonFormField...');
                    print('🔧 Items a agregar: ${loadedVehicles.length + 1}');
                    
                    final items = <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: 'sin_vehiculo',
                        child: Text('Sin vehículo asignado'),
                      ),
                      ...loadedVehicles.map((vehicle) {
                        print('   ➕ Agregando: ${vehicle.placa}');
                        return DropdownMenuItem<String>(
                          value: vehicle.id,
                          child: Text(
                            '${vehicle.placa} - ${vehicle.marca} ${vehicle.modelo}',
                          ),
                        );
                      }),
                    ];
                    
                    print('🔧 Total items en dropdown: ${items.length}');
                    
                    return DropdownButtonFormField<String>(
                      key: ValueKey('dropdown_${loadedVehicles.length}_${DateTime.now().millisecondsSinceEpoch}'),
                      value: 'sin_vehiculo',
                      decoration: InputDecoration(
                        labelText: 'Vehículo asignado (Opcional)',
                        hintText: loadedVehicles.isEmpty
                            ? 'No hay vehículos disponibles'
                            : 'Selecciona un vehículo',
                        prefixIcon: const Icon(Icons.directions_car),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: items,
                      onChanged: (value) {
                        print('📝 Vehículo seleccionado: $value');
                        _selectedVehicleIdForNewDriver = value;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Usuario
                TextFormField(
                  controller: _usernameController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Usuario *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Solo números (ej: número de cédula)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El usuario es requerido';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                      return 'El usuario debe contener solo números';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña *',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Mínimo 6 caracteres',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La contraseña es requerida';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Botón crear
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isCreating || _rateLimitSeconds > 0)
                        ? null
                        : () async {
                            final success = await _handleCreateDriver();
                            if (mounted && success) {
                              Navigator.of(context).pop();
                              _usernameController.clear();
                              _passwordController.clear();
                              _fullNameController.clear();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isCreating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _rateLimitSeconds > 0
                        ? Text(
                            'ESPERAR $_rateLimitSeconds SEGUNDOS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Text(
                            'CREAR CONDUCTOR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
