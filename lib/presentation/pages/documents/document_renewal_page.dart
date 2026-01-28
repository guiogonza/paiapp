import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/document_repository_impl.dart';
import 'package:pai_app/domain/entities/document_entity.dart';

class DocumentRenewalPage extends StatefulWidget {
  final DocumentEntity document;

  const DocumentRenewalPage({super.key, required this.document});

  @override
  State<DocumentRenewalPage> createState() => _DocumentRenewalPageState();
}

class _DocumentRenewalPageState extends State<DocumentRenewalPage> {
  final _documentRepository = DocumentRepositoryImpl();
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  DateTime? _newExpirationDate;
  File? _selectedImage;
  XFile? _selectedXFile;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Renovar ${widget.document.documentType}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información del documento actual
              Card(
                color: AppColors.background,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documento Actual',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tipo: ${widget.document.documentType}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expira: ${DateFormat('dd/MM/yyyy').format(widget.document.expirationDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: widget.document.isExpired
                              ? Colors.red
                              : widget.document.isExpiringSoon
                              ? Colors.orange
                              : AppColors.textSecondary,
                          fontWeight:
                              widget.document.isExpired ||
                                  widget.document.isExpiringSoon
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nueva fecha de expiración
              Text(
                'Nueva Fecha de Expiración *',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectExpirationDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.lightGray),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _newExpirationDate != null
                              ? DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_newExpirationDate!)
                              : 'Seleccionar fecha',
                          style: TextStyle(
                            color: _newExpirationDate != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_newExpirationDate == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'La fecha de expiración es obligatoria',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),

              // Nueva imagen del documento
              Text(
                'Nueva Imagen del Documento *',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_selectedImage != null || _selectedXFile != null)
                Container(
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.lightGray),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            _selectedXFile!.path,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload_file),
                label: const Text('Seleccionar Imagen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_selectedImage == null && _selectedXFile == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'La imagen del documento es obligatoria',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
              const SizedBox(height: 32),

              // Botón de guardar
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleRenewal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Renovar Documento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  Future<void> _selectExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _newExpirationDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 años
      helpText: 'Seleccionar nueva fecha de expiración',
    );

    if (picked != null) {
      setState(() {
        _newExpirationDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedXFile = pickedFile;
          _selectedImage = null;
        });
      }
    } else {
      // Verificar permisos en móvil
      final status = await Permission.photos.status;
      if (!status.isGranted) {
        final result = await Permission.photos.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se necesitan permisos para acceder a las fotos'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedXFile = null;
        });
      }
    }
  }

  Future<void> _handleRenewal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newExpirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una fecha de expiración'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedImage == null && _selectedXFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una imagen del documento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Subir la nueva imagen
      List<int> imageBytes;
      String fileName;

      if (kIsWeb && _selectedXFile != null) {
        imageBytes = await _selectedXFile!.readAsBytes();
        fileName =
            'document_${widget.document.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else if (_selectedImage != null) {
        imageBytes = await _selectedImage!.readAsBytes();
        fileName =
            'document_${widget.document.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else {
        throw Exception('No se seleccionó ninguna imagen');
      }

      final uploadResult = await _documentRepository.uploadDocumentImage(
        imageBytes,
        fileName,
      );
      final imageUrl = uploadResult.fold(
        (failure) => throw Exception(failure.message),
        (url) => url,
      );

      // 2. Crear el nuevo documento
      // TODO: Obtener usuario actual desde backend
      const currentUserId = 'user@example.com';

      final newDocument = DocumentEntity(
        vehicleId: widget.document.vehicleId,
        driverId: widget.document.driverId,
        documentType: widget.document.documentType,
        expirationDate: _newExpirationDate!,
        documentUrl: imageUrl,
        createdBy: currentUserId,
        isArchived: false,
      );

      // 3. Renovar el documento (archiva el antiguo y crea el nuevo)
      final renewResult = await _documentRepository.renewDocument(
        widget.document.id!,
        newDocument,
      );

      renewResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al renovar documento: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Documento renovado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true); // Retornar true para indicar éxito
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
