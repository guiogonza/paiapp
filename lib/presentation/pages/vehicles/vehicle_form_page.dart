import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/core/utils/validators.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

class VehicleFormPage extends StatefulWidget {
  final VehicleEntity? vehicle;

  const VehicleFormPage({super.key, this.vehicle});

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anoController = TextEditingController();
  final _conductorController = TextEditingController();
  final _repository = VehicleRepositoryImpl();

  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _placaController.text = widget.vehicle!.placa;
      _marcaController.text = widget.vehicle!.marca;
      _modeloController.text = widget.vehicle!.modelo;
      _anoController.text = widget.vehicle!.ano.toString();
      _conductorController.text = widget.vehicle!.conductor ?? '';
    }

    // Validar formulario inicialmente
    _validateForm();

    // Agregar listeners para validación en tiempo real
    _placaController.addListener(_validateForm);
    _marcaController.addListener(_validateForm);
    _modeloController.addListener(_validateForm);
    _anoController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _conductorController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sanitizar placa
      final placa = Validators.sanitizePlaca(_placaController.text);
      final ano = int.parse(_anoController.text.trim());

      final vehicle = VehicleEntity(
        id: widget.vehicle?.id,
        placa: placa,
        marca: _marcaController.text.trim(),
        modelo: _modeloController.text.trim(),
        ano: ano,
        conductor: _conductorController.text.trim().isEmpty
            ? null
            : _conductorController.text.trim(),
      );

      final result = widget.vehicle == null
          ? await _repository.createVehicle(vehicle)
          : await _repository.updateVehicle(vehicle);

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
        (savedVehicle) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.vehicle == null
                      ? 'Vehículo registrado exitosamente'
                      : 'Vehículo actualizado exitosamente',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop(savedVehicle);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Nuevo Vehículo' : 'Editar Vehículo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          onChanged: _validateForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Placa Field
              TextFormField(
                controller: _placaController,
                decoration: InputDecoration(
                  labelText: 'Placa',
                  hintText: 'ABC123',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: Validators.validatePlaca,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Marca Field
              TextFormField(
                controller: _marcaController,
                decoration: InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Toyota',
                  prefixIcon: const Icon(Icons.branding_watermark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    Validators.validateRequired(value, 'Marca'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Modelo Field
              TextFormField(
                controller: _modeloController,
                decoration: InputDecoration(
                  labelText: 'Modelo',
                  hintText: 'Corolla',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    Validators.validateRequired(value, 'Modelo'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Año Field
              TextFormField(
                controller: _anoController,
                decoration: InputDecoration(
                  labelText: 'Año',
                  hintText: '2024',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: Validators.validateAno,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Conductor Field (Opcional)
              TextFormField(
                controller: _conductorController,
                decoration: InputDecoration(
                  labelText: 'Conductor (Opcional)',
                  hintText: 'Nombre del conductor',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (_isFormValid && !_isLoading) {
                    _handleSave();
                  }
                },
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

