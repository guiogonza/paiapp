import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/repositories/trip_repository_impl.dart';
import 'package:pai_app/data/services/profitability_service.dart';
import 'package:pai_app/domain/entities/profitability_record_entity.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/presentation/utils/excel_export_utils.dart';

class ProfitabilityByRoutePage extends StatefulWidget {
  const ProfitabilityByRoutePage({super.key});

  @override
  State<ProfitabilityByRoutePage> createState() => _ProfitabilityByRoutePageState();
}

class _ProfitabilityByRoutePageState extends State<ProfitabilityByRoutePage> {
  final _tripRepository = TripRepositoryImpl();
  final _profitabilityService = ProfitabilityService();
  
  List<TripEntity> _trips = [];
  String? _selectedOrigin;
  String? _selectedDestination;
  DateTime? _fromDate;
  DateTime? _toDate;
  List<ProfitabilityRecordEntity> _records = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    // Por defecto, rango del mes actual
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _loadTrips() async {
    final result = await _tripRepository.getTrips();
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar viajes: ${failure.message}')),
          );
        }
      },
      (trips) {
        if (mounted) {
          setState(() {
            _trips = trips;
          });
        }
      },
    );
  }

  List<String> get _uniqueOrigins {
    return _trips.map((t) => t.origin).whereType<String>().toSet().toList()..sort();
  }

  List<String> get _uniqueDestinations {
    return _trips.map((t) => t.destination).whereType<String>().toSet().toList()..sort();
  }

  Future<void> _searchRecords() async {
    if (_selectedOrigin == null || _selectedDestination == null || _fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final records = await _profitabilityService.getRecordsByRoute(
        origin: _selectedOrigin!,
        destination: _selectedDestination!,
        fromDate: _fromDate!,
        toDate: _toDate!,
      );

      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar registros: $e')),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    try {
      final fileName = 'rentabilidad_ruta_${_selectedOrigin}_${_selectedDestination}_${DateFormat('yyyy-MM-dd').format(_fromDate!)}_${DateFormat('yyyy-MM-dd').format(_toDate!)}.xlsx';
      await ExcelExportUtils.exportProfitabilityRecords(
        records: _records,
        fileName: fileName,
        title: 'Rentabilidad por Ruta - $_selectedOrigin → $_selectedDestination',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archivo Excel generado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentabilidad por Ruta'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.orange),
              onPressed: _exportToExcel,
              tooltip: 'Exportar a Excel',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Selector de origen
                DropdownButtonFormField<String>(
                  value: _selectedOrigin,
                  decoration: InputDecoration(
                    labelText: 'Origen *',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _uniqueOrigins.map((origin) {
                    return DropdownMenuItem(
                      value: origin,
                      child: Text(origin),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOrigin = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Selector de destino
                DropdownButtonFormField<String>(
                  value: _selectedDestination,
                  decoration: InputDecoration(
                    labelText: 'Destino *',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _uniqueDestinations.map((destination) {
                    return DropdownMenuItem(
                      value: destination,
                      child: Text(destination),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDestination = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Rango de fechas
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Desde *',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _fromDate != null
                                ? DateFormat('dd/MM/yyyy').format(_fromDate!)
                                : 'Seleccionar fecha',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Hasta *',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _toDate != null
                                ? DateFormat('dd/MM/yyyy').format(_toDate!)
                                : 'Seleccionar fecha',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botón de búsqueda
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchRecords,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Buscando...' : 'Buscar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tabla de resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasSearched && _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sin datos',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : _records.isEmpty
                        ? const SizedBox()
                        : _buildRecordsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTable() {
    final numberFormat = NumberFormat('#,###', 'es_CO');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.1)),
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('Ingresos')),
            DataColumn(label: Text('Gastos Viaje')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Tipo Gasto')),
            DataColumn(label: Text('Vehículo')),
          ],
          rows: _records.map((record) {
            return DataRow(
              cells: [
                DataCell(Text(DateFormat('dd/MM/yyyy').format(record.date))),
                DataCell(
                  Chip(
                    label: Text(
                      record.isIncome ? 'Ingreso' : 'G. Viaje',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: record.isIncome
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                  ),
                ),
                DataCell(Text(
                  record.isIncome ? '\$${numberFormat.format(record.amount)}' : '-',
                  style: TextStyle(
                    color: record.isIncome ? Colors.green : Colors.grey,
                    fontWeight: record.isIncome ? FontWeight.bold : FontWeight.normal,
                  ),
                )),
                DataCell(Text(
                  record.isTripExpense ? '\$${numberFormat.format(record.amount)}' : '-',
                  style: TextStyle(
                    color: record.isTripExpense ? Colors.orange : Colors.grey,
                    fontWeight: record.isTripExpense ? FontWeight.bold : FontWeight.normal,
                  ),
                )),
                DataCell(Text(record.clientName ?? '-')),
                DataCell(Text(record.expenseType ?? '-')),
                DataCell(Text(record.vehiclePlate ?? '-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

