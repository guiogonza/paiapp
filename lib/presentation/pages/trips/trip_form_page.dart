import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/core/utils/validators.dart';
import 'package:pai_app/data/repositories/trip_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/domain/entities/profile_entity.dart';

class TripFormPage extends StatefulWidget {
  final TripEntity? trip;

  const TripFormPage({super.key, this.trip});

  @override
  State<TripFormPage> createState() => _TripFormPageState();
}

class _TripFormPageState extends State<TripFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _driverNameController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _revenueAmountController = TextEditingController();
  final _budgetAmountController = TextEditingController();
  final _tripRepository = TripRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  final _profileRepository = ProfileRepositoryImpl();

  String? _selectedVehicleId;
  String? _selectedDriverId;
  List<VehicleEntity> _vehicles = [];
  bool _isLoadingDrivers = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isFormValid = false;
  bool _isCurrentUserDriver = false;
  List<ProfileEntity> _drivers = [];

  @override
  void initState() {
    super.initState();
    _startDate = widget.trip?.startDate ?? DateTime.now(); // Por defecto hoy
    _loadVehicles();
    if (widget.trip != null) {
      _selectedVehicleId = widget.trip!.vehicleId;
      _driverNameController.text = widget.trip!.driverName;
      _clientNameController.text = widget.trip!.clientName;
      _originController.text = widget.trip!.origin;
      _destinationController.text = widget.trip!.destination;
      _revenueAmountController.text = widget.trip!.revenueAmount.toStringAsFixed(0);
      _budgetAmountController.text = widget.trip!.budgetAmount.toStringAsFixed(0);
      _endDate = widget.trip!.endDate;
    }
    _loadUserAndDrivers();

    // Validar formulario inicialmente
    _validateForm();

    // Agregar listeners para validación en tiempo real
    _driverNameController.addListener(_validateForm);
    _clientNameController.addListener(_validateForm);
    _originController.addListener(_validateForm);
    _destinationController.addListener(_validateForm);
    _revenueAmountController.addListener(_validateForm);
    _budgetAmountController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _clientNameController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _revenueAmountController.dispose();
    _budgetAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndDrivers() async {
    try {
      final profileResult = await _profileRepository.getCurrentUserProfile();
      profileResult.fold(
        (failure) {
          // Si falla, asumimos owner para no bloquear el formulario
          _isCurrentUserDriver = false;
        },
        (profile) {
          _isCurrentUserDriver = profile.role == 'driver';

          if (widget.trip == null && _isCurrentUserDriver) {
            // Conductor: fijar su propio email y vehículo asignado
            _selectedDriverId = profile.id;
            _driverNameController.text = profile.email ?? '';
            final assignedVehicleId = profile.assignedVehicleId;
            if (assignedVehicleId != null && assignedVehicleId.isNotEmpty) {
              _selectedVehicleId = assignedVehicleId;
              // Cargar los datos completos del vehículo asignado
              _loadVehicleForCurrentDriver(assignedVehicleId);
            } else {
              _selectedVehicleId = null;
            }
          }
        },
      );

      if (!_isCurrentUserDriver) {
        // Owner: cargar lista de conductores con vehículo asignado
        final driversResult =
            await _profileRepository.getDriversWithAssignedVehicle();
        driversResult.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _drivers = [];
                _isLoadingDrivers = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Error al cargar conductores: ${failure.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          (drivers) {
            if (mounted) {
              setState(() {
                _drivers = drivers;
                _isLoadingDrivers = false;
              });
            }
          },
        );
      } else {
        if (mounted) {
          setState(() {
            _isLoadingDrivers = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDrivers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos de usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Carga el vehículo asignado al conductor actual (por id) y
  /// lo agrega a la lista local para poder mostrar la placa.
  Future<void> _loadVehicleForCurrentDriver(String vehicleId) async {
    final result = await _vehicleRepository.getVehicleById(vehicleId);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo cargar el vehículo asignado: ${failure.message}',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      (vehicle) {
        if (!mounted) return;
        setState(() {
          // Actualizar o agregar el vehículo a la lista local
          final index =
              _vehicles.indexWhere((v) => v.id != null && v.id == vehicle.id);
          if (index >= 0) {
            _vehicles[index] = vehicle;
          } else {
            _vehicles.add(vehicle);
          }
          // Asegurar que el id seleccionado coincida
          if (vehicle.id != null) {
            _selectedVehicleId = vehicle.id;
          }
        });
        _validateForm();
      },
    );
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
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      (vehicles) {
        if (mounted) {
          setState(() {
            _vehicles = vehicles;
          });
          _validateForm();
        }
      },
    );
  }

  void _validateForm() {
    final formValid = _formKey.currentState?.validate() ?? false;
    final vehicleSelected =
        _selectedVehicleId != null && _selectedVehicleId!.isNotEmpty;
    final isValid = formValid && vehicleSelected;
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _selectStartDate() async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _startDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: AppColors.textOnPrimary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _startDate = picked;
          // Si la fecha de fin es anterior a la de inicio, limpiarla
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        });
        _validateForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar fecha: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectEndDate() async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _endDate ?? _startDate ?? DateTime.now(),
        firstDate: _startDate ?? DateTime(2000),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: AppColors.textOnPrimary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _endDate = picked;
        });
        _validateForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar fecha: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVehicleId == null || _selectedVehicleId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un vehículo'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final revenueAmount = double.tryParse(_revenueAmountController.text.trim());
      if (revenueAmount == null || revenueAmount <= 0) {
        throw Exception('El monto de ingreso debe ser un número válido mayor a 0');
      }

      final budgetAmount = double.tryParse(_budgetAmountController.text.trim());
      if (budgetAmount == null || budgetAmount <= 0) {
        throw Exception(
            'El anticipo de viaje debe ser un número válido mayor a 0');
      }

      final trip = TripEntity(
        id: widget.trip?.id,
        vehicleId: _selectedVehicleId!,
        driverName: _driverNameController.text.trim(),
        clientName: _clientNameController.text.trim(),
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        revenueAmount: revenueAmount,
        budgetAmount: budgetAmount,
        startDate: _startDate,
        endDate: _endDate,
      );

      final result = widget.trip == null
          ? await _tripRepository.createTrip(trip)
          : await _tripRepository.updateTrip(trip);

      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        (savedTrip) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.trip == null
                      ? 'Viaje registrado exitosamente'
                      : 'Viaje actualizado exitosamente',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop(savedTrip);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'No seleccionada';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _buildSelectedVehicleLabel() {
    if (_selectedVehicleId == null || _selectedVehicleId!.isEmpty) {
      return 'Sin vehículo asignado';
    }
    VehicleEntity? vehicle;
    for (final v in _vehicles) {
      if (v.id == _selectedVehicleId) {
        vehicle = v;
        break;
      }
    }
    if (vehicle == null) {
      return 'Vehículo no encontrado';
    }
    return '${vehicle.placa} - ${vehicle.marca} ${vehicle.modelo}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip == null ? 'Nuevo Viaje' : 'Editar Viaje'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          onChanged: _validateForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Conductor y vehículo asignado
              if (_isCurrentUserDriver)
                TextFormField(
                  controller: _driverNameController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Conductor',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText:
                        'Conductor actual (solo puede crear viajes para sí mismo)',
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedDriverId,
                  decoration: InputDecoration(
                    labelText: 'Conductor *',
                    hintText: _isLoadingDrivers
                        ? 'Cargando conductores...'
                        : 'Selecciona un conductor',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _isLoadingDrivers
                      ? const [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Cargando conductores...'),
                          ),
                        ]
                      : _drivers.map((driver) {
                          final email = driver.email ?? '';
                          final fullName = driver.fullName ?? '';
                          final hasName = fullName.trim().isNotEmpty;
                          final label =
                              hasName ? '$fullName ($email)' : email;
                          return DropdownMenuItem<String>(
                            value: driver.id,
                            child: Text(label),
                          );
                        }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDriverId = value;
                      final selected = _drivers.firstWhere(
                        (d) => d.id == value,
                        orElse: () => _drivers.first,
                      );
                      _driverNameController.text = selected.email ?? '';
                      _selectedVehicleId = selected.assignedVehicleId;
                    });
                    _validateForm();
                  },
                  validator: (value) {
                    if (_isCurrentUserDriver) {
                      return null;
                    }
                    if (value == null || value.isEmpty) {
                      return 'Debes seleccionar un conductor';
                    }
                    final selected = _drivers.firstWhere(
                      (d) => d.id == value,
                      orElse: () => _drivers.first,
                    );
                    if ((selected.assignedVehicleId ?? '').isEmpty) {
                      return 'Este conductor no tiene vehículo asignado';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              // Mostrar el vehículo asociado (solo informativo)
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Vehículo (asignado automáticamente)',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _buildSelectedVehicleLabel(),
                  style: TextStyle(
                    color: _selectedVehicleId != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Client Name (Cliente) - Obligatorio
              TextFormField(
                controller: _clientNameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Cliente *',
                  hintText: 'Nombre del cliente',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    Validators.validateRequired(value, 'Nombre del Cliente'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Origen - Obligatorio
              TextFormField(
                controller: _originController,
                decoration: InputDecoration(
                  labelText: 'Origen *',
                  hintText: 'Ciudad o lugar de origen',
                  prefixIcon: const Icon(Icons.place),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    Validators.validateRequired(value, 'Origen'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Destino - Obligatorio
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(
                  labelText: 'Destino *',
                  hintText: 'Ciudad o lugar de destino',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    Validators.validateRequired(value, 'Destino'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Monto de Ingreso (revenue_amount) - Obligatorio, Numérico
              TextFormField(
                controller: _revenueAmountController,
                decoration: InputDecoration(
                  labelText: 'Monto de Ingreso *',
                  hintText: '0',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El monto de ingreso es requerido';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null) {
                    return 'Ingresa un monto válido';
                  }
                  if (amount <= 0) {
                    return 'El monto debe ser mayor a 0';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Presupuesto de Gastos (budget_amount) - Obligatorio, Numérico
              TextFormField(
                controller: _budgetAmountController,
                decoration: InputDecoration(
                  labelText: 'Anticipo de viaje *',
                  hintText: '0',
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El anticipo de viaje es requerido';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null) {
                    return 'Ingresa un anticipo válido';
                  }
                  if (amount <= 0) {
                    return 'El anticipo debe ser mayor a 0';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Start Date
              InkWell(
                onTap: _selectStartDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de Inicio',
                    hintText: 'Selecciona la fecha',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _formatDate(_startDate),
                    style: TextStyle(
                      color: _startDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // End Date
              InkWell(
                onTap: _selectEndDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de Fin',
                    hintText: 'Selecciona la fecha',
                    prefixIcon: const Icon(Icons.event),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _formatDate(_endDate),
                    style: TextStyle(
                      color: _endDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isFormValid && !_isLoading) ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    disabledBackgroundColor: AppColors.lightGray,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'GUARDAR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
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

