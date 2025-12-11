import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/document_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/domain/entities/document_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

class DocumentsManagementPage extends StatefulWidget {
  const DocumentsManagementPage({super.key});

  @override
  State<DocumentsManagementPage> createState() => _DocumentsManagementPageState();
}

class _DocumentsManagementPageState extends State<DocumentsManagementPage> {
  final _documentRepository = DocumentRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  final _profileRepository = ProfileRepositoryImpl();
  final _imagePicker = ImagePicker();

  List<DocumentEntity> _documents = [];
  List<VehicleEntity> _vehicles = [];
  Map<String, String> _driverNames = {}; // driver_id -> email/name
  bool _isLoading = true;

  // Formulario
  final _formKey = GlobalKey<FormState>();
  String? _selectedAssociationType; // 'vehicle' o 'driver'
  String? _selectedVehicleId;
  String? _selectedDriverId;
  final _documentTypeController = TextEditingController();
  DateTime? _selectedExpirationDate;
  File? _selectedImage;
  XFile? _selectedXFile;
  String? _existingImageUrl;
  bool _isSaving = false;

  static const List<String> _associationTypes = ['Vehículo', 'Conductor'];
  static const List<String> _commonDocumentTypes = [
    'SOAT',
    'Técnico Mecánica',
    'Seguro',
    'Licencia de Conducción',
    'Tarjeta de Operación',
    'Permiso de Circulación',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _documentTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar documentos
      final documentsResult = await _documentRepository.getDocuments();
      documentsResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar documentos: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (documents) {
          _documents = documents;
        },
      );

      // Cargar vehículos
      final vehiclesResult = await _vehicleRepository.getVehicles();
      vehiclesResult.fold(
        (failure) {
          // Ignorar errores
        },
        (vehicles) {
          _vehicles = vehicles;
        },
      );

      // Cargar conductores
      await _loadDrivers();
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

  Future<void> _loadDrivers() async {
    print('🔄 Recargando lista de conductores...');
    final driversResult = await _profileRepository.getDriversList();
    driversResult.fold(
      (failure) {
        print('❌ Error al cargar conductores: ${failure.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar conductores: ${failure.message}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() {
            _driverNames = {}; // Asegurar que esté vacío en caso de error
          });
        }
      },
      (driversMap) {
        print('✅ Conductores cargados: ${driversMap.length}');
        if (mounted) {
          setState(() {
            _driverNames = driversMap;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lista de conductores actualizada: ${driversMap.length} encontrados'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // Mostrar advertencia si no hay conductores
          if (driversMap.isEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay conductores registrados en el sistema. Por favor, crea usuarios con rol "driver" primero.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      },
    );
  }


  Future<void> _pickImage() async {
    try {
      // Solicitar permiso de cámara si no está en web
      if (!kIsWeb) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Se necesita permiso de cámara para tomar fotos. Por favor, habilítalo en la configuración de la app.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Abrir Configuración',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          _selectedXFile = image;
          if (!kIsWeb) {
            _selectedImage = File(image.path);
          }
          _existingImageUrl = null;
        });
      }
    } on PlatformException catch (e) {
      // Manejo específico de errores de plataforma (permisos, etc.)
      String errorMessage = 'Error al acceder a la cámara';
      if (e.code == 'camera_access_denied' || e.code == 'permission_denied') {
        errorMessage = 'Permiso de cámara denegado. Por favor, habilita el permiso en la configuración de la app.';
      } else if (e.code == 'camera_unavailable') {
        errorMessage = 'Cámara no disponible';
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Manejo genérico de otros errores
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      // Solicitar permiso de galería si no está en web
      if (!kIsWeb) {
        Permission? storagePermission = Platform.isAndroid 
            ? Permission.photos 
            : Permission.photos;
        
        final status = await storagePermission.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Se necesita permiso de galería para seleccionar imágenes. Por favor, habilítalo en la configuración de la app.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Abrir Configuración',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          _selectedXFile = image;
          if (!kIsWeb) {
            _selectedImage = File(image.path);
          }
          _existingImageUrl = null;
        });
      }
    } on PlatformException catch (e) {
      // Manejo específico de errores de plataforma (permisos, etc.)
      String errorMessage = 'Error al acceder a la galería';
      if (e.code == 'photo_access_denied' || e.code == 'permission_denied') {
        errorMessage = 'Permiso de galería denegado. Por favor, habilita el permiso en la configuración de la app.';
      } else if (e.code == 'photo_picker_unavailable') {
        errorMessage = 'Selector de fotos no disponible';
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Manejo genérico de otros errores
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAssociationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar si el documento es de un Vehículo o Conductor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAssociationType == 'Vehículo' && _selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un vehículo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAssociationType == 'Conductor' && _selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un conductor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedExpirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una fecha de expiración'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? documentUrl = _existingImageUrl;

      // Subir imagen si hay una nueva (opcional - no bloquea el guardado si falla)
      if (_selectedXFile != null || _selectedImage != null) {
        try {
          final fileBytes = kIsWeb && _selectedXFile != null
              ? await _selectedXFile!.readAsBytes()
              : await _selectedImage!.readAsBytes();
          
          final fileName = 'document_${DateTime.now().millisecondsSinceEpoch}.${kIsWeb && _selectedXFile != null ? _selectedXFile!.name.split('.').last : 'jpg'}';
          
          final uploadResult = await _documentRepository.uploadDocumentImage(fileBytes, fileName);
          uploadResult.fold(
            (failure) {
              // Si falla la subida de imagen, continuar sin imagen (es opcional)
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Advertencia: No se pudo subir la imagen. El documento se guardará sin imagen. ${failure.message}'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              // documentUrl permanece null o como _existingImageUrl
            },
            (url) {
              documentUrl = url;
            },
          );
        } catch (uploadError) {
          // Si hay un error al leer o subir la imagen, continuar sin imagen
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Advertencia: Error al procesar la imagen. El documento se guardará sin imagen.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // documentUrl permanece null o como _existingImageUrl
        }
      }

      final document = DocumentEntity(
        vehicleId: _selectedAssociationType == 'Vehículo' ? _selectedVehicleId : null,
        driverId: _selectedAssociationType == 'Conductor' ? _selectedDriverId : null,
        documentType: _documentTypeController.text.trim(),
        expirationDate: _selectedExpirationDate!,
        documentUrl: documentUrl,
      );

      final result = await _documentRepository.createDocument(document);
      
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al guardar: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Documento guardado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            // Limpiar formulario
            _formKey.currentState!.reset();
            _selectedAssociationType = null;
            _selectedVehicleId = null;
            _selectedDriverId = null;
            _selectedExpirationDate = null;
            _selectedImage = null;
            _selectedXFile = null;
            _existingImageUrl = null;
            // Recargar datos
            _loadData();
          }
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
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _selectExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpirationDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // 10 años
      locale: const Locale('es', 'ES'),
    );

    if (picked != null) {
      setState(() {
        _selectedExpirationDate = picked;
      });
    }
  }

  String _getAssociatedName(DocumentEntity document) {
    if (document.isVehicleDocument) {
      final vehicle = _vehicles.firstWhere(
        (v) => v.id == document.vehicleId,
        orElse: () => VehicleEntity(
          id: document.vehicleId!,
          placa: 'Desconocido',
          marca: '',
          modelo: '',
          ano: 0,
        ),
      );
      return 'Vehículo: ${vehicle.placa}';
    } else if (document.isDriverDocument) {
      final driverName = _driverNames[document.driverId] ?? document.driverId ?? 'Desconocido';
      return 'Conductor: $driverName';
    }
    return 'No asociado';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Documentos / Gestión'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos / Gestión'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar todo',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh_drivers') {
                _loadDrivers();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh_drivers',
                child: Row(
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 8),
                    Text('Actualizar lista de conductores'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de Alertas
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
                        Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Alertas de Documentos',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_documents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.description, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No hay documentos registrados',
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
                      ..._documents.map((document) => _buildDocumentAlertItem(document)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sección de Registro
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Registrar Nuevo Documento',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tipo de Asociación
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAssociationType,
                        decoration: InputDecoration(
                          labelText: 'Asociar a *',
                          prefixIcon: const Icon(Icons.link),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _associationTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAssociationType = value;
                            _selectedVehicleId = null;
                            _selectedDriverId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Selector de Vehículo
                      if (_selectedAssociationType == 'Vehículo')
                        DropdownButtonFormField<String>(
                          initialValue: _selectedVehicleId,
                          decoration: InputDecoration(
                            labelText: 'Vehículo *',
                            prefixIcon: const Icon(Icons.directions_car),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _vehicles.map((vehicle) {
                            return DropdownMenuItem(
                              value: vehicle.id,
                              child: Text('${vehicle.placa} - ${vehicle.marca} ${vehicle.modelo}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedVehicleId = value;
                            });
                          },
                        ),

                      // Selector de Conductor
                      if (_selectedAssociationType == 'Conductor')
                        _driverNames.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No hay conductores registrados. Por favor, crea usuarios con rol "driver" primero.',
                                        style: TextStyle(
                                          color: Colors.orange[800],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                initialValue: _selectedDriverId,
                                decoration: InputDecoration(
                                  labelText: 'Conductor *',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText: _driverNames.isEmpty
                                      ? 'No hay conductores disponibles'
                                      : '${_driverNames.length} conductor(es) disponible(s)',
                                ),
                                items: _driverNames.entries.map((entry) {
                                  return DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDriverId = value;
                                  });
                                },
                                validator: (value) {
                                  if (_selectedAssociationType == 'Conductor' && (value == null || value.isEmpty)) {
                                    return 'Debes seleccionar un conductor';
                                  }
                                  return null;
                                },
                              ),

                      if (_selectedAssociationType != null) const SizedBox(height: 16),

                      // Tipo de Documento
                      TextFormField(
                        controller: _documentTypeController,
                        decoration: InputDecoration(
                          labelText: 'Tipo de Documento *',
                          hintText: 'Ej: SOAT, Licencia, Seguro...',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (value) {
                              _documentTypeController.text = value;
                            },
                            itemBuilder: (context) {
                              return _commonDocumentTypes.map((type) {
                                return PopupMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El tipo de documento es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Fecha de Expiración
                      InkWell(
                        onTap: _selectExpirationDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fecha de Expiración *',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _selectedExpirationDate != null
                                ? DateFormat('dd/MM/yyyy').format(_selectedExpirationDate!)
                                : 'Selecciona la fecha',
                            style: TextStyle(
                              color: _selectedExpirationDate != null
                                  ? AppColors.textPrimary
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Imagen del Documento (Opcional)
                      Text(
                        'Imagen del Documento (Opcional)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickImageFromGallery,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Seleccionar de Galería'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Tomar Foto'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedXFile != null || _selectedImage != null || _existingImageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Imagen seleccionada',
                                style: TextStyle(color: Colors.green),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _selectedXFile = null;
                                    _existingImageUrl = null;
                                  });
                                },
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Botón Guardar
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'GUARDAR DOCUMENTO',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentAlertItem(DocumentEntity document) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isExpiringSoon = document.isExpiringSoon;
    final isExpired = document.isExpired;
    final daysUntilExpiration = document.daysUntilExpiration;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: isExpired
          ? Colors.red.withValues(alpha: 0.1)
          : isExpiringSoon
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isExpired
              ? Colors.red
              : isExpiringSoon
                  ? Colors.orange
                  : Colors.transparent,
          width: isExpired || isExpiringSoon ? 2 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Icono de alerta
            if (isExpired || isExpiringSoon)
              Icon(
                isExpired ? Icons.error : Icons.warning,
                color: isExpired ? Colors.red : Colors.orange,
                size: 32,
              )
            else
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
            const SizedBox(width: 12),
            // Información del documento
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.documentType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isExpired ? Colors.red[700] : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getAssociatedName(document),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expira: ${dateFormat.format(document.expirationDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired
                          ? Colors.red[700]
                          : isExpiringSoon
                              ? Colors.orange[700]
                              : Colors.grey[600],
                      fontWeight: isExpired || isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isExpired)
                    Text(
                      'EXPIRADO hace ${-daysUntilExpiration} días',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (isExpiringSoon)
                    Text(
                      'Expira en $daysUntilExpiration días',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            // Botón para ver documento si existe
            if (document.documentUrl != null && document.documentUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () {
                  // Mostrar imagen en diálogo
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppBar(
                            title: Text(document.documentType),
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
                                document.documentUrl!,
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
                        ],
                      ),
                    ),
                  );
                },
                tooltip: 'Ver documento',
              ),
          ],
        ),
      ),
    );
  }
}

