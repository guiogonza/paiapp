import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/remittance_repository_impl.dart';
import 'package:pai_app/data/repositories/expense_repository_impl.dart';
import 'package:pai_app/domain/entities/remittance_with_route_entity.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';

class RemittanceSigningPage extends StatefulWidget {
  final RemittanceWithRouteEntity remittanceWithRoute;
  final VoidCallback onRemittanceUpdated;

  const RemittanceSigningPage({
    super.key,
    required this.remittanceWithRoute,
    required this.onRemittanceUpdated,
  });

  @override
  State<RemittanceSigningPage> createState() => _RemittanceSigningPageState();
}

class _RemittanceSigningPageState extends State<RemittanceSigningPage> {
  final RemittanceRepositoryImpl _remittanceRepository =
      RemittanceRepositoryImpl();
  final ExpenseRepositoryImpl _expenseRepository = ExpenseRepositoryImpl();
  final _formKey = GlobalKey<FormState>();
  final _receivedByController = TextEditingController();

  File? _selectedImage;
  XFile? _selectedXFile;
  bool _isLoading = false;
  bool _hasImage = false;
  List<ExpenseEntity> _driverExpenses = [];
  bool _isLoadingExpenses = false;

  @override
  void initState() {
    super.initState();
    // Verificar si ya hay una imagen adjunta
    _hasImage =
        widget.remittanceWithRoute.remittance.receiptUrl != null &&
        widget.remittanceWithRoute.remittance.receiptUrl!.isNotEmpty;
    // Cargar historial de gastos del conductor para este viaje
    _loadDriverExpenses();
  }

  Future<void> _loadDriverExpenses() async {
    final tripId = widget.remittanceWithRoute.tripId;
    final currentUserId = 'user_1';

    if (tripId == null || tripId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingExpenses = true;
    });

    final result = await _expenseRepository.getExpensesByTripIdAndDriver(
      tripId,
      currentUserId,
    );

    result.fold(
      (failure) {
        // No mostrar error, simplemente no mostrar gastos
        if (mounted) {
          setState(() {
            _isLoadingExpenses = false;
          });
        }
      },
      (expenses) {
        if (mounted) {
          setState(() {
            _driverExpenses = expenses;
            _isLoadingExpenses = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _receivedByController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (kIsWeb) {
            _selectedXFile = pickedFile;
            _selectedImage = null;
          } else {
            _selectedImage = File(pickedFile.path);
            _selectedXFile = null;
          }
          _hasImage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (kIsWeb) {
            _selectedXFile = pickedFile;
            _selectedImage = null;
          } else {
            _selectedImage = File(pickedFile.path);
            _selectedXFile = null;
          }
          _hasImage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleFinalize() async {
    if (!_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes adjuntar una foto del memorando para finalizar'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? receiptUrl;

      // Generar un nombre de archivo limpio y simple basado en el ID de la remisión
      // IMPORTANTE: El nombre debe ser el mismo para subir y obtener la URL
      final remittanceId =
          widget.remittanceWithRoute.remittance.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Determinar la extensión del archivo
      String fileExtension = 'jpg'; // Por defecto
      if (kIsWeb && _selectedXFile != null) {
        final originalName = _selectedXFile!.name.toLowerCase();
        if (originalName.endsWith('.png')) {
          fileExtension = 'png';
        } else if (originalName.endsWith('.jpeg') ||
            originalName.endsWith('.jpg')) {
          fileExtension = 'jpg';
        }
      } else if (_selectedImage != null) {
        final originalPath = _selectedImage!.path.toLowerCase();
        if (originalPath.endsWith('.png')) {
          fileExtension = 'png';
        } else if (originalPath.endsWith('.jpeg') ||
            originalPath.endsWith('.jpg')) {
          fileExtension = 'jpg';
        }
      }

      // Nombre de archivo limpio: remittance_{id}.{extension}
      final cleanFileName = 'remittance_$remittanceId.$fileExtension';

      // Subir la imagen
      if (kIsWeb && _selectedXFile != null) {
        final fileBytes = await _selectedXFile!.readAsBytes();

        final uploadResult = await _remittanceRepository.uploadMemorandumImage(
          fileBytes,
          cleanFileName, // Usar el nombre limpio
        );
        await uploadResult.fold(
          (failure) {
            throw Exception(failure.message);
          },
          (url) {
            receiptUrl = url;
          },
        );
      } else if (_selectedImage != null) {
        final fileBytes = await _selectedImage!.readAsBytes();

        final uploadResult = await _remittanceRepository.uploadMemorandumImage(
          fileBytes,
          cleanFileName, // Usar el mismo nombre limpio
        );
        await uploadResult.fold(
          (failure) {
            throw Exception(failure.message);
          },
          (url) {
            receiptUrl = url;
          },
        );
      } else if (widget.remittanceWithRoute.remittance.receiptUrl != null) {
        // Si ya había una imagen, usar la existente
        receiptUrl = widget.remittanceWithRoute.remittance.receiptUrl;
      }

      // Actualizar la remittance con receipt_url y cambiar el status a pendiente_cobrar
      final updatedRemittance = widget.remittanceWithRoute.remittance.copyWith(
        receiptUrl: receiptUrl,
        receiverName: _receivedByController.text.trim().isNotEmpty
            ? _receivedByController.text.trim()
            : widget.remittanceWithRoute.remittance.receiverName,
        status: 'pendiente_cobrar', // CRÍTICO: Cambiar el estado al finalizar
        updatedAt: DateTime.now(),
      );

      final updateResult = await _remittanceRepository.updateRemittance(
        updatedRemittance,
      );

      updateResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al finalizar: ${failure.message}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
        },
        (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Remisión finalizada exitosamente'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            widget.onRemittanceUpdated();
            Navigator.of(context).pop();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firmar Remisión')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información de la remisión
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
                      Text(
                        'Información del Viaje',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Cliente',
                        widget.remittanceWithRoute.clientName?.isNotEmpty ==
                                true
                            ? widget.remittanceWithRoute.clientName!
                            : widget.remittanceWithRoute.receiverName,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Ruta',
                        '${widget.remittanceWithRoute.startLocation} → ${widget.remittanceWithRoute.endLocation}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Fecha',
                        widget.remittanceWithRoute.createdAt != null
                            ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(widget.remittanceWithRoute.createdAt!)
                            : 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Historial de Gastos del Conductor
              if (_driverExpenses.isNotEmpty) ...[
                _buildExpensesHistorySection(),
                const SizedBox(height: 24),
              ],

              // Botón gigante para adjuntar foto (OBLIGATORIO)
              Text(
                'Foto del Memorando *',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Tomar Foto'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Seleccionar de Galería'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImageFromGallery();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _hasImage ? Colors.green : Colors.orange,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _hasImage
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                    ),
                    child: _hasImage
                        ? Stack(
                            children: [
                              Center(
                                child: kIsWeb && _selectedXFile != null
                                    ? Image.network(
                                        _selectedXFile!.path,
                                        fit: BoxFit.contain,
                                      )
                                    : _selectedImage != null
                                    ? Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.contain,
                                      )
                                    : widget
                                              .remittanceWithRoute
                                              .remittance
                                              .receiptUrl !=
                                          null
                                    ? Image.network(
                                        widget
                                            .remittanceWithRoute
                                            .remittance
                                            .receiptUrl!,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(Icons.image, size: 80),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 64,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Toca para adjuntar foto',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'OBLIGATORIO',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Campo "Recibido por" (OPCIONAL)
              TextFormField(
                controller: _receivedByController,
                decoration: InputDecoration(
                  labelText: 'Recibido por (Opcional)',
                  hintText: 'Nombre de quien recibe',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),

              // Botón Finalizar
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleFinalize,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isLoading ? 'Finalizando...' : 'Finalizar Remisión',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildExpensesHistorySection() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );
    final totalAmount = _driverExpenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Mis Gastos Registrados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingExpenses)
              const Center(child: CircularProgressIndicator())
            else if (_driverExpenses.isEmpty)
              Text(
                'No hay gastos registrados para este viaje',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              )
            else ...[
              ..._driverExpenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              dateFormat.format(expense.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(expense.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    currencyFormat.format(totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
