import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
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
  final _mileageController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isLoadingMileage = false;

  static const List<String> _maintenanceTypes = [
    'Aceite',
    'Llantas',
    'Batería',
    'Frenos',
    'Filtros',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadVehicles();
  }

  @override
  void dispose() {
    _costController.dispose();
    _mileageController.dispose();
    _descriptionController.dispose();
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
    if (_selectedVehicle?.gpsDeviceId == null || _selectedVehicle!.gpsDeviceId!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMileage = true;
    });

    final result = await _maintenanceRepository.getLiveGpsMileage(_selectedVehicle!.gpsDeviceId!);
    
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al obtener kilometraje GPS: ${failure.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      (mileage) {
        if (mounted && mileage != null) {
          setState(() {
            _mileageController.text = mileage.toStringAsFixed(2);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kilometraje GPS cargado'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );

    if (mounted) {
      setState(() {
        _isLoadingMileage = false;
      });
    }
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
    final mileage = double.tryParse(_mileageController.text) ?? 0.0;

    final maintenance = MaintenanceEntity(
      vehicleId: _selectedVehicle!.id!,
      type: _selectedType!,
      cost: cost,
      date: _selectedDate ?? DateTime.now(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      createdBy: currentUser.id,
    );

    final result = await _maintenanceRepository.registerMaintenance(maintenance, mileage);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Mantenimiento'),
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
                onChanged: (vehicle) {
                  setState(() {
                    _selectedVehicle = vehicle;
                    // Si el vehículo tiene gps_device_id, cargar kilometraje GPS
                    if (vehicle?.gpsDeviceId != null && vehicle!.gpsDeviceId!.isNotEmpty) {
                      _loadGpsMileage();
                    } else if (vehicle?.currentMileage != null) {
                      // Si no hay GPS pero hay kilometraje guardado, usarlo
                      _mileageController.text = vehicle!.currentMileage!.toStringAsFixed(2);
                    }
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecciona un vehículo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de kilometraje con botón para cargar desde GPS
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mileageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Kilometraje (km) *',
                        prefixIcon: const Icon(Icons.speed),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText: _selectedVehicle?.gpsDeviceId != null 
                            ? 'Toca el botón para cargar desde GPS'
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa el kilometraje';
                        }
                        final mileage = double.tryParse(value);
                        if (mileage == null || mileage < 0) {
                          return 'Kilometraje inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_selectedVehicle?.gpsDeviceId != null && _selectedVehicle!.gpsDeviceId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: IconButton(
                        icon: _isLoadingMileage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        onPressed: _isLoadingMileage ? null : _loadGpsMileage,
                        tooltip: 'Cargar desde GPS',
                        color: AppColors.primary,
                      ),
                    ),
                ],
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
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.3),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

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

              // Fecha
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                        : 'Selecciona una fecha',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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

