import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/expense_repository_impl.dart';
import 'package:pai_app/data/repositories/trip_repository_impl.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';

class ExpenseFormPage extends StatefulWidget {
  final ExpenseEntity? expense;

  const ExpenseFormPage({super.key, this.expense});

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _expenseRepository = ExpenseRepositoryImpl();
  final _tripRepository = TripRepositoryImpl();
  final _imagePicker = ImagePicker();

  String? _selectedRouteId;
  List<TripEntity> _activeTrips = [];
  bool _isLoadingRoutes = true;
  String? _selectedCategory;
  DateTime? _selectedDate;
  File? _selectedImage;
  XFile? _selectedXFile; // Para web, guardar el XFile directamente
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isFormValid = false;

  // Categorías estrictas
  static const List<String> _categories = [
    'Gasolina',
    'Comida',
    'Peajes',
    'Hoteles',
    'Repuestos',
    'Arreglos',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _loadActiveRoutes();
    if (widget.expense != null) {
      _selectedRouteId = widget.expense!.routeId;
      _amountController.text = widget.expense!.amount.toStringAsFixed(0);
      _descriptionController.text = widget.expense!.description ?? '';
      _selectedCategory = widget.expense!.category;
      _selectedDate = widget.expense!.date;
      _existingImageUrl = widget.expense!.receiptUrl;
    } else {
      _selectedDate = DateTime.now();
    }

    // Validar formulario inicialmente
    _validateForm();

    // Agregar listeners para validación en tiempo real
    _amountController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
    });

    final result = await _tripRepository.getTrips();

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar viajes: ${failure.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isLoadingRoutes = false;
          });
        }
      },
      (trips) {
        if (mounted) {
          // Filtrar viajes activos: end_date es null o está en el futuro
          final now = DateTime.now();
          final activeTrips = trips.where((trip) {
            if (trip.endDate == null) return true;
            return trip.endDate!.isAfter(now) || trip.endDate!.isAtSameMomentAs(now);
          }).toList();

          setState(() {
            _activeTrips = activeTrips;
            _isLoadingRoutes = false;
          });
          _validateForm();
        }
      },
    );
  }

  void _validateForm() {
    final formValid = _formKey.currentState?.validate() ?? false;
    final routeSelected = _selectedRouteId != null && _selectedRouteId!.isNotEmpty;
    final categorySelected = _selectedCategory != null && _selectedCategory!.isNotEmpty;
    final dateSelected = _selectedDate != null;
    final isValid = formValid && routeSelected && categorySelected && dateSelected;
    
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _selectDate() async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
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
          _selectedDate = picked;
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

  Future<void> _pickImage() async {
    try {
      ImageSource source;
      
      // En web, solo usar galería (la cámara no funciona)
      if (kIsWeb) {
        source = ImageSource.gallery;
      } else {
        // En móvil, mostrar opciones: Cámara o Galería
        final selectedSource = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Seleccionar de galería'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
        
        if (selectedSource == null) return;
        source = selectedSource;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          // Guardar el XFile para usar sus bytes directamente
          _selectedXFile = image;
          // También guardar como File para compatibilidad
          if (!kIsWeb) {
            _selectedImage = File(image.path);
          }
          _existingImageUrl = null; // Limpiar URL existente si se selecciona nueva imagen
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _selectedXFile = null;
      _existingImageUrl = null;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRouteId == null || _selectedRouteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un viaje activo'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una categoría'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una fecha'),
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
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        throw Exception('El monto debe ser un número válido mayor a 0');
      }

      String? receiptUrl = _existingImageUrl;

      // Si hay una nueva imagen, subirla
      if (_selectedXFile != null || _selectedImage != null) {
        // Si había una imagen anterior, eliminarla
        if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
          await _expenseRepository.deleteReceiptImage(_existingImageUrl!);
        }

        // En web, usar los bytes del XFile directamente
        if (kIsWeb && _selectedXFile != null) {
          final fileBytes = await _selectedXFile!.readAsBytes();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedXFile!.name}';
          
          final uploadResult = await _expenseRepository.uploadReceiptImageFromBytes(fileBytes, fileName);
          uploadResult.fold(
            (failure) {
              throw Exception(failure.message);
            },
            (url) {
              receiptUrl = url;
            },
          );
        } else if (_selectedImage != null) {
          // En móvil, usar el path del File
          final uploadResult = await _expenseRepository.uploadReceiptImage(_selectedImage!.path);
          uploadResult.fold(
            (failure) {
              throw Exception(failure.message);
            },
            (url) {
              receiptUrl = url;
            },
          );
        }
      }

      final expense = ExpenseEntity(
        id: widget.expense?.id,
        routeId: _selectedRouteId!,
        amount: amount,
        date: _selectedDate!,
        category: _selectedCategory!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        receiptUrl: receiptUrl,
      );

      final result = widget.expense == null
          ? await _expenseRepository.createExpense(expense)
          : await _expenseRepository.updateExpense(expense);

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
        (savedExpense) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.expense == null
                      ? 'Gasto registrado exitosamente'
                      : 'Gasto actualizado exitosamente',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop(savedExpense);
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
    if (date == null) return 'Selecciona la fecha';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getTripDisplayName(TripEntity trip) {
    return '${trip.driverName} - ${DateFormat('dd/MM/yyyy').format(trip.startDate ?? DateTime.now())}';
  }

  Future<Widget> _buildImagePreview() async {
    if (_selectedXFile != null) {
      // En web, usar los bytes del XFile
      if (kIsWeb) {
        final bytes = await _selectedXFile!.readAsBytes();
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
        );
      } else if (_selectedImage != null) {
        return Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
        );
      }
    } else if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
      );
    } else if (_existingImageUrl != null) {
      return Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.error, color: Colors.red),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Nuevo Gasto' : 'Editar Gasto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          onChanged: _validateForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de Viaje Activo (Dropdown) - Obligatorio
              DropdownButtonFormField<String>(
                value: _selectedRouteId,
                decoration: InputDecoration(
                  labelText: 'Viaje Activo *',
                  hintText: 'Selecciona un viaje activo',
                  prefixIcon: const Icon(Icons.route),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _isLoadingRoutes
                    ? [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Cargando viajes...'),
                        )
                      ]
                    : _activeTrips.isEmpty
                        ? [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No hay viajes activos'),
                            )
                          ]
                        : _activeTrips.map((trip) {
                            return DropdownMenuItem<String>(
                              value: trip.id,
                              child: Text(_getTripDisplayName(trip)),
                            );
                          }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRouteId = value;
                  });
                  _validateForm();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Debes seleccionar un viaje activo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Categoría (Dropdown) - Obligatorio con opciones estrictas
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Categoría *',
                  hintText: 'Selecciona una categoría',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                  _validateForm();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Debes seleccionar una categoría';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Monto (amount) - Obligatorio, Numérico
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Monto *',
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
                    return 'El monto es requerido';
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

              // Fecha (date) - Obligatorio
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha *',
                    hintText: 'Selecciona la fecha',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _formatDate(_selectedDate),
                    style: TextStyle(
                      color: _selectedDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Descripción (Opcional)
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  hintText: 'Descripción del gasto',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),

              // Subida de Foto
              Text(
                'Recibo (Opcional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Agregar Foto'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_selectedXFile != null || _selectedImage != null || _existingImageUrl != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _removeImage,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar imagen',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Miniatura de la foto
              if (_selectedXFile != null || _selectedImage != null || _existingImageUrl != null)
                FutureBuilder<Widget>(
                  future: _buildImagePreview(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lightGray),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: snapshot.data ?? const SizedBox(),
                      ),
                    );
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

