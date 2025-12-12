import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/core/constants/maintenance_rules.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/maintenance_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceFormPage extends StatefulWidget {
  const MaintenanceFormPage({super.key});

  @override
  State<MaintenanceFormPage> createState() => _MaintenanceFormPageState();
}

class _MaintenanceFormPageState extends State<MaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  
  List<VehicleEntity> _vehicles = [];
  VehicleEntity? _selectedVehicle;
  String? _selectedType;
  final _costController = TextEditingController();
  final _customServiceNameController = TextEditingController();
  double? _currentMileage; // Kilometraje actual (readonly, desde GPS)
  DateTime? _serviceDate;
  DateTime? _alertDate; // Fecha de aviso (opcional para estándar, obligatorio para "Otro")
  bool _isLoading = false;
  bool _isLoadingMileage = false;

  static const List<String> _maintenanceTypes = [
    'Aceite',
    'Llantas',
    'Frenos',
    'Filtro Aire',
    'Batería',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _serviceDate = DateTime.now();
    _loadVehicles();
  }

  @override
  void dispose() {
    _costController.dispose();
    _customServiceNameController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final result = await _vehicleRepository.getVehicles();
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar vehículos: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (vehicles) {
        if (mounted) {
          setState(() {
            _vehicles = vehicles;
          });
        }
      },
    );
  }

  Future<void> _loadGpsMileage() async {
    print('🔍 _loadGpsMileage llamado para vehículo: ${_selectedVehicle?.placa}');
    print('🔍 GPS Device ID: ${_selectedVehicle?.gpsDeviceId}');
    
    if (_selectedVehicle?.gpsDeviceId == null || _selectedVehicle!.gpsDeviceId!.isEmpty) {
      print('⚠️ No hay GPS Device ID en BD, usando current_mileage del vehículo');
      // Si no hay GPS Device ID, NO intentar buscar en todos los dispositivos
      // Esto previene el bug de datos cruzados
      if (_selectedVehicle?.currentMileage != null) {
        setState(() {
          _isLoadingMileage = false;
          _currentMileage = _selectedVehicle!.currentMileage;
        });
        print('✅ Usando kilometraje guardado: ${_currentMileage} km');
      } else {
        setState(() {
          _isLoadingMileage = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingMileage = true;
    });

    print('🔍 Llamando getLiveGpsMileage con deviceId: ${_selectedVehicle!.gpsDeviceId}');
    final result = await _maintenanceRepository.getLiveGpsMileage(_selectedVehicle!.gpsDeviceId!);
    print('🔍 Resultado recibido: ${result.isRight() ? "Right" : "Left"}');
    
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoadingMileage = false;
            // Si falla GPS, usar current_mileage como fallback
            if (_selectedVehicle?.currentMileage != null) {
              _currentMileage = _selectedVehicle!.currentMileage;
            }
          });
          // Solo mostrar error si no hay fallback disponible
          if (_currentMileage == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar GPS: ${failure.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Usando kilometraje guardado: ${_currentMileage!.toStringAsFixed(1)} km'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      (mileage) {
        print('🔍 Callback Right ejecutado, mileage recibido: $mileage');
        if (mounted) {
          setState(() {
            _isLoadingMileage = false;
            _currentMileage = mileage ?? _selectedVehicle?.currentMileage;
          });
          print('🔍 Estado actualizado, _currentMileage: $_currentMileage');
          if (mileage != null) {
            print('✅ Mostrando mensaje de éxito con kilometraje: ${mileage.toStringAsFixed(1)} km');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kilometraje GPS cargado: ${mileage.toStringAsFixed(1)} km'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            print('⚠️ mileage es null, usando fallback');
            if (_currentMileage != null) {
              // Si mileage es null pero hay currentMileage del vehículo, usar ese
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Usando kilometraje guardado: ${_currentMileage!.toStringAsFixed(1)} km'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              print('❌ No hay kilometraje disponible (ni GPS ni guardado)');
            }
          }
        }
      },
    );
  }

  /// Calcula el km de próximo cambio basado en las reglas (SIN umbral)
  double? _calculateNextChangeKm() {
    if (_selectedType == null || _currentMileage == null) return null;
    return MaintenanceRules.calculateNextChangeKm(_currentMileage!, _selectedType!);
  }


  /// Obtiene el texto informativo para tipos estándar
  String? _getInfoText() {
    if (_selectedType == null || _currentMileage == null) return null;
    
    if (!MaintenanceRules.isStandardType(_selectedType!)) return null;
    
    final kmInterval = MaintenanceRules.getKmInterval(_selectedType!);
    if (kmInterval != null) {
      final nextChangeKm = _calculateNextChangeKm();
      final alertKm = MaintenanceRules.calculateAlertKm(_currentMileage!, _selectedType!);
      return 'Próximo cambio: ${nextChangeKm?.toStringAsFixed(0) ?? 'N/A'} km. Alerta a los ${alertKm?.toStringAsFixed(0) ?? 'N/A'} km (${MaintenanceRules.alertKmThreshold} km antes)';
    }
    
    final yearInterval = MaintenanceRules.getYearInterval(_selectedType!);
    if (yearInterval != null) {
      final nextChangeDate = MaintenanceRules.calculateNextChangeDate(_serviceDate ?? DateTime.now(), _selectedType!);
      final alertDate = MaintenanceRules.calculateAlertDate(_serviceDate ?? DateTime.now(), _selectedType!);
      if (nextChangeDate != null && alertDate != null) {
        return 'Próximo cambio: ${DateFormat('dd/MM/yyyy').format(nextChangeDate)} (+$yearInterval años). Alerta: ${DateFormat('dd/MM/yyyy').format(alertDate)} (${MaintenanceRules.alertDaysThreshold} días antes)';
      }
    }
    
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un vehículo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un tipo de mantenimiento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentMileage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carga el kilometraje desde GPS o selecciona un vehículo con kilometraje'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario no autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final cost = double.tryParse(_costController.text) ?? 0.0;

    // Calcular next_change_km y alert_date según las reglas
    // IMPORTANTE: next_change_km se guarda SIN umbral (km donde se debe hacer el cambio)
    // La alerta se activa cuando current_mileage >= (next_change_km - 2000)
    double? nextChangeKm;
    DateTime? alertDate;

    if (_selectedType == 'Otro') {
      // Para "Otro", usar la fecha de aviso proporcionada por el usuario
      // La alerta es 30 días antes de la fecha manual
      if (_alertDate != null) {
        alertDate = MaintenanceRules.calculateAlertDateFromManual(_alertDate!);
      }
      // No hay next_change_km para "Otro"
    } else {
      // Para tipos estándar, calcular automáticamente
      // next_change_km = km actual + intervalo (SIN umbral)
      nextChangeKm = MaintenanceRules.calculateNextChangeKm(_currentMileage!, _selectedType!);
      
      // alert_date: Si el usuario proporcionó fecha manual, calcular alerta 30 días antes
      // Si no, calcular automáticamente desde serviceDate
      if (_alertDate != null) {
        // Fecha manual: alerta 30 días antes
        alertDate = MaintenanceRules.calculateAlertDateFromManual(_alertDate!);
      } else {
        // Fecha automática: calcular desde serviceDate y restar 30 días
        alertDate = MaintenanceRules.calculateAlertDate(_serviceDate ?? DateTime.now(), _selectedType!);
      }
    }

    // Para "Otro", el serviceType debe ser "Otro" y el nombre personalizado va en customServiceName
    final maintenance = MaintenanceEntity(
      vehicleId: _selectedVehicle!.id!,
      serviceType: _selectedType!, // Siempre el tipo seleccionado (incluye "Otro")
      serviceDate: _serviceDate ?? DateTime.now(),
      kmAtService: _currentMileage!,
      nextChangeKm: nextChangeKm, // KM donde se debe hacer el cambio (sin umbral)
      alertDate: alertDate, // Fecha de alerta anticipada (con umbral de 30 días)
      cost: cost,
      customServiceName: _selectedType == 'Otro' ? _customServiceNameController.text.trim() : null,
      createdBy: currentUser.id,
    );

    final result = await _maintenanceRepository.registerMaintenance(maintenance);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al registrar mantenimiento: ${failure.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      },
      (createdMaintenance) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mantenimiento registrado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOtherType = _selectedType == 'Otro';
    final isStandardType = _selectedType != null && MaintenanceRules.isStandardType(_selectedType!);
    final infoText = _getInfoText();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Mantenimiento'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de vehículo
              DropdownButtonFormField<VehicleEntity>(
                value: _selectedVehicle,
                decoration: InputDecoration(
                  labelText: 'Vehículo *',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _vehicles.map((vehicle) {
                  return DropdownMenuItem(
                    value: vehicle,
                    child: Text(vehicle.placa),
                  );
                }).toList(),
                onChanged: (vehicle) async {
                  if (vehicle == null) return;
                  
                  // DEBUG CRÍTICO: Verificar datos del vehículo seleccionado
                  debugPrint('--- [DEBUG CRÍTICO] Vehículo seleccionado: ${vehicle.placa} ---');
                  debugPrint('--- [DEBUG CRÍTICO] ID del vehículo: ${vehicle.id} ---');
                  debugPrint('--- [DEBUG CRÍTICO] GPS Device ID desde objeto: ${vehicle.gpsDeviceId} ---');
                  
                  // Relectura del vehículo desde BD para asegurar datos completos
                  if (vehicle.id != null) {
                    final vehicleResult = await _vehicleRepository.getVehicleById(vehicle.id!);
                    vehicleResult.fold(
                      (failure) {
                        debugPrint('--- [DEBUG CRÍTICO] Error al releer vehículo: ${failure.message} ---');
                        // Si falla la relectura, usar el vehículo seleccionado
                        setState(() {
                          _selectedVehicle = vehicle;
                          _currentMileage = null;
                        });
                        _loadGpsMileage();
                      },
                      (freshVehicle) {
                        debugPrint('--- [DEBUG CRÍTICO] ID LEÍDO DESDE BD: ${freshVehicle.gpsDeviceId} ---');
                        debugPrint('--- [DEBUG CRÍTICO] Current Mileage desde BD: ${freshVehicle.currentMileage} ---');
                        
                        setState(() {
                          _selectedVehicle = freshVehicle; // Usar vehículo recién leído
                          _currentMileage = null; // Resetear kilometraje
                        });
                        
                        // Solo cargar GPS si tiene gpsDeviceId
                        if (freshVehicle.gpsDeviceId != null && freshVehicle.gpsDeviceId!.isNotEmpty) {
                          _loadGpsMileage();
                        } else {
                          debugPrint('--- [DEBUG CRÍTICO] Vehículo NO tiene gpsDeviceId, usando currentMileage ---');
                          if (freshVehicle.currentMileage != null) {
                            setState(() {
                              _currentMileage = freshVehicle.currentMileage;
                            });
                          }
                        }
                      },
                    );
                  } else {
                    // Si no tiene ID, usar el vehículo seleccionado directamente
                    setState(() {
                      _selectedVehicle = vehicle;
                      _currentMileage = null;
                    });
                    _loadGpsMileage();
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecciona un vehículo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kilometraje actual (readonly, informativo)
              if (_currentMileage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.royalBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: AppColors.royalBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kilometraje Actual',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${_currentMileage!.toStringAsFixed(0)} km',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedVehicle?.gpsDeviceId != null && _selectedVehicle!.gpsDeviceId!.isNotEmpty)
                        IconButton(
                          icon: _isLoadingMileage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          onPressed: _isLoadingMileage ? null : _loadGpsMileage,
                          tooltip: 'Actualizar desde GPS',
                          color: AppColors.royalBlue,
                        ),
                    ],
                  ),
                )
              else if (_selectedVehicle != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isLoadingMileage
                              ? 'Cargando kilometraje desde GPS...'
                              : 'No se pudo cargar el kilometraje. Selecciona un vehículo con GPS o kilometraje guardado.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Tipo de mantenimiento (Chips)
              const Text(
                'Tipo de Mantenimiento *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _maintenanceTypes.map((type) {
                  final isSelected = _selectedType == type;
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = selected ? type : null;
                        _customServiceNameController.clear();
                        _alertDate = null;
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.3),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Campo "Nombre del Servicio" solo para "Otro"
              if (isOtherType)
                TextFormField(
                  controller: _customServiceNameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Servicio *',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (isOtherType && (value == null || value.trim().isEmpty)) {
                      return 'Ingresa el nombre del servicio';
                    }
                    return null;
                  },
                ),
              if (isOtherType) const SizedBox(height: 16),

              // Texto informativo para tipos estándar
              if (isStandardType && infoText != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.royalBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.royalBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.royalBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          infoText,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isStandardType && infoText != null) const SizedBox(height: 16),

              // Costo
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Costo *',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el costo';
                  }
                  final cost = double.tryParse(value);
                  if (cost == null || cost < 0) {
                    return 'Costo inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fecha del servicio
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _serviceDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _serviceDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha del Servicio *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _serviceDate != null
                        ? DateFormat('dd/MM/yyyy').format(_serviceDate!)
                        : 'Selecciona una fecha',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fecha de Aviso (obligatorio para "Otro", opcional para estándar)
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _alertDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setState(() {
                      _alertDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: isOtherType ? 'Fecha de Aviso *' : 'Fecha de Aviso (Opcional)',
                    prefixIcon: const Icon(Icons.notifications),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: isOtherType 
                        ? 'Define cuándo quieres que te avisemos'
                        : 'Opcional: Si no defines fecha, se usará la regla automática',
                  ),
                  child: Text(
                    _alertDate != null
                        ? DateFormat('dd/MM/yyyy').format(_alertDate!)
                        : isOtherType
                            ? 'Selecciona una fecha *'
                            : 'Opcional: Selecciona una fecha',
                    style: TextStyle(
                      color: _alertDate != null 
                          ? AppColors.textPrimary 
                          : (isOtherType ? Colors.red : AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              if (isOtherType)
                Builder(
                  builder: (context) {
                    if (_alertDate == null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'La fecha de aviso es obligatoria para servicios personalizados',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              const SizedBox(height: 24),

              // Botón guardar
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'REGISTRAR MANTENIMIENTO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
