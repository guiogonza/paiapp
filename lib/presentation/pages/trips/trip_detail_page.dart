import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Import condicional para web
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/expense_repository_impl.dart';
import 'package:pai_app/data/repositories/trip_repository_impl.dart';
import 'package:pai_app/data/repositories/remittance_repository_impl.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/entities/remittance_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/presentation/pages/expenses/expense_form_page.dart';

/// Vista de detalle del viaje para el Owner
/// Muestra todos los gastos asociados al viaje y calcula la rentabilidad
class TripDetailPage extends StatefulWidget {
  final String tripId;

  const TripDetailPage({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  final _tripRepository = TripRepositoryImpl();
  final _expenseRepository = ExpenseRepositoryImpl();
  final _remittanceRepository = RemittanceRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  
  TripEntity? _trip;
  RemittanceEntity? _remittance;
  List<ExpenseEntity> _allExpenses = [];
  final Map<String, String> _driverNames = {}; // Map driver_id -> email/name
  bool _isLoading = true;
  VehicleEntity? _vehicle;

  @override
  void initState() {
    super.initState();
    _loadTripAndExpenses();
  }

  Future<void> _loadTripAndExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar el viaje
      final tripResult = await _tripRepository.getTripById(widget.tripId);
      tripResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar viaje: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (trip) async {
          _trip = trip;

          // Cargar vehículo asociado para mostrar placa
          final vehicleResult =
              await _vehicleRepository.getVehicleById(trip.vehicleId);
          vehicleResult.fold(
            (failure) {
              _vehicle = null;
            },
            (vehicle) {
              _vehicle = vehicle;
            },
          );
        },
      );

      // Cargar todos los gastos del viaje
      final expensesResult = await _expenseRepository.getExpensesByTripId(widget.tripId);
      expensesResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al cargar gastos: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (expenses) {
          _allExpenses = expenses;
          // Obtener nombres de los conductores
          _loadDriverNames(expenses);
        },
      );

      // Cargar la remisión del viaje
      final remittanceResult = await _remittanceRepository.getRemittanceByTripId(widget.tripId);
      remittanceResult.fold(
        (failure) {
          // No mostrar error, simplemente no hay remisión
        },
        (remittance) {
          _remittance = remittance;
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

  Future<void> _loadDriverNames(List<ExpenseEntity> expenses) async {
    final driverIds = expenses
        .where((e) => e.driverId != null)
        .map((e) => e.driverId!)
        .toSet();

    for (final driverId in driverIds) {
      try {
        // Intentar obtener desde profiles
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name, email')
            .eq('id', driverId)
            .maybeSingle();

        if (profileResponse != null) {
          final name = profileResponse['full_name'] as String?;
          final email = profileResponse['email'] as String?;
          _driverNames[driverId] = name ?? email ?? driverId;
        } else {
          // Si no hay perfil, usar el ID como fallback
          _driverNames[driverId] = driverId;
        }
      } catch (e) {
        // En caso de error, usar el ID
        _driverNames[driverId] = driverId;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  double _calculateTotalExpenses() {
    return _allExpenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );
  }

  double _calculateProfit() {
    if (_trip == null) return 0.0;
    return _trip!.revenueAmount - _calculateTotalExpenses();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Viaje'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Viaje'),
        ),
        body: const Center(
          child: Text('Viaje no encontrado'),
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final totalExpenses = _calculateTotalExpenses();
    final profit = _calculateProfit();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Viaje'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTripAndExpenses,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTripAndExpenses,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información del Viaje
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
                          'Ruta', '${_trip!.origin} → ${_trip!.destination}'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Cliente', _trip!.clientName),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                          'Conductor',
                          _trip!.driverName.isNotEmpty
                              ? _trip!.driverName
                              : 'Sin asignar'),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Vehículo',
                        _vehicle != null ? _vehicle!.placa : 'Sin información',
                      ),
                      if (_trip!.startDate != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Fecha de Inicio', dateFormat.format(_trip!.startDate!)),
                      ],
                      if (_trip!.endDate != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Fecha de Fin', dateFormat.format(_trip!.endDate!)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Estado de la Remisión
              if (_remittance != null) ...[
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getStatusIcon(_remittance!.status),
                                  color: _getStatusColor(_remittance!.status),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Estado de Remisión',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            // Botones de ver y descargar remisión (si hay foto y estado es pendiente_cobrar o cobrado)
                            if ((_remittance!.status == 'pendiente_cobrar' || _remittance!.status == 'cobrado') &&
                                _remittance!.receiptUrl != null &&
                                _remittance!.receiptUrl!.isNotEmpty) ...[
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () => _viewRemittanceImage(_remittance!),
                                tooltip: 'Ver remisión',
                                color: AppColors.primary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () => _downloadRemittanceImage(_remittance!),
                                tooltip: 'Descargar remisión',
                                color: AppColors.accent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_remittance!.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(_remittance!.status),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _getStatusLabel(_remittance!.status),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(_remittance!.status),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Resultado del Viaje (Rentabilidad)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: profit >= 0 
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            profit >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: profit >= 0 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Resultado del Viaje',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFinancialRow(
                        'Ingreso',
                        currencyFormat.format(_trip!.revenueAmount),
                        Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildFinancialRow(
                        'Gasto Total',
                        currencyFormat.format(totalExpenses),
                        Colors.orange,
                      ),
                      const Divider(height: 24),
                      _buildFinancialRow(
                        'Resultado',
                        currencyFormat.format(profit),
                        profit >= 0 ? Colors.green : Colors.red,
                        isBold: true,
                        fontSize: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Historial de Gastos
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(
                                'Historial de Gastos',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExpenseFormPage(tripId: widget.tripId),
                                ),
                              ).then((_) => _loadTripAndExpenses());
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Registrar Gasto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_allExpenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay gastos registrados',
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
                        ..._allExpenses.map((expense) => _buildExpenseItem(
                              expense,
                              dateFormat,
                              currencyFormat,
                            )),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    double fontSize = 16,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseItem(
    ExpenseEntity expense,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    final driverName = expense.driverId != null
        ? _driverNames[expense.driverId] ?? 'Desconocido'
        : 'Sin asignar';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(expense.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (expense.description != null && expense.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          expense.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Registrado por: $driverName',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(expense.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image, size: 20),
                            onPressed: () => _showReceiptImage(expense.receiptUrl!),
                            tooltip: 'Ver recibo',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download, size: 20),
                            onPressed: () => _downloadReceiptImage(expense.receiptUrl!, expense.type, expense.date),
                            tooltip: 'Descargar recibo',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Recibo'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    _downloadReceiptImage(imageUrl, 'recibo', DateTime.now());
                    Navigator.of(context).pop();
                  },
                  tooltip: 'Descargar',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
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
  }

  void _downloadReceiptImage(String imageUrl, String expenseType, DateTime expenseDate) {
    if (kIsWeb) {
      // En web, usar dart:html para descargar
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
    } else {
      // En móvil, abrir la URL
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En dispositivos móviles, toca la imagen para descargarla'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendiente_completar':
        return Colors.orange;
      case 'pendiente_cobrar':
        return Colors.blue;
      case 'cobrado':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pendiente_completar':
        return Icons.pending;
      case 'pendiente_cobrar':
        return Icons.payment;
      case 'cobrado':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pendiente_completar':
        return 'Pendiente Completar';
      case 'pendiente_cobrar':
        return 'Pendiente Cobrar';
      case 'cobrado':
        return 'Cobrado';
      default:
        return status;
    }
  }

  void _viewRemittanceImage(RemittanceEntity remittance) {
    if (remittance.receiptUrl == null || remittance.receiptUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay remisión adjunta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar imagen en diálogo
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Remisión Adjunta'),
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
                  remittance.receiptUrl!,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _downloadRemittanceImage(remittance);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Descargar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadRemittanceImage(RemittanceEntity remittance) async {
    if (remittance.receiptUrl == null || remittance.receiptUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay remisión adjunta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (kIsWeb) {
      try {
        // Mostrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
                SizedBox(width: 16),
                Text('Descargando imagen...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );

        // Descargar la imagen usando http
        final response = await http.get(Uri.parse(remittance.receiptUrl!));
        if (response.statusCode == 200) {
          // Crear un Blob con los bytes
          final blob = html.Blob([response.bodyBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          
          // Crear un elemento anchor y descargar
          final dateStr = remittance.createdAt != null
              ? DateFormat('yyyy-MM-dd').format(remittance.createdAt!)
              : 'remision';
          final fileName = 'remision_$dateStr.jpg';
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          
          // Limpiar la URL del objeto
          html.Url.revokeObjectUrl(url);
          
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Descarga completada'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw Exception('Error al descargar: ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al descargar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Para móvil, abrir la URL en el navegador
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abre: ${remittance.receiptUrl}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

