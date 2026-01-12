import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pai_app/core/theme/app_colors.dart';
import 'package:pai_app/data/services/profitability_service.dart';
import 'package:pai_app/domain/entities/profitability_record_entity.dart';
import 'package:pai_app/presentation/utils/excel_export_utils.dart';

class ProfitabilityGlobalPage extends StatefulWidget {
  const ProfitabilityGlobalPage({super.key});

  @override
  State<ProfitabilityGlobalPage> createState() => _ProfitabilityGlobalPageState();
}

class _ProfitabilityGlobalPageState extends State<ProfitabilityGlobalPage> {
  final _profitabilityService = ProfitabilityService();
  
  DateTime? _fromDate;
  DateTime? _toDate;
  List<ProfitabilityRecordEntity> _records = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  
  // Filtros
  String? _filterType; // 'ingreso', 'gasto_viaje', 'gasto_mantenimiento', null (todos)
  String? _filterVehiclePlate;
  String? _filterClientName;

  @override
  void initState() {
    super.initState();
    // Por defecto, rango del mes actual
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _searchRecords() async {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona el rango de fechas')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final allRecords = await _profitabilityService.getGlobalRecords(
        fromDate: _fromDate!,
        toDate: _toDate!,
      );

      // Aplicar filtros
      List<ProfitabilityRecordEntity> filteredRecords = allRecords;
      
      if (_filterType != null) {
        filteredRecords = filteredRecords.where((r) {
          if (_filterType == 'ingreso') return r.isIncome;
          if (_filterType == 'gasto_viaje') return r.isTripExpense;
          if (_filterType == 'gasto_mantenimiento') return r.isMaintenanceExpense;
          return true;
        }).toList();
      }

      if (_filterVehiclePlate != null && _filterVehiclePlate!.isNotEmpty) {
        filteredRecords = filteredRecords.where((r) {
          return r.vehiclePlate?.toLowerCase().contains(_filterVehiclePlate!.toLowerCase()) ?? false;
        }).toList();
      }

      if (_filterClientName != null && _filterClientName!.isNotEmpty) {
        filteredRecords = filteredRecords.where((r) {
          return r.clientName?.toLowerCase().contains(_filterClientName!.toLowerCase()) ?? false;
        }).toList();
      }

      if (mounted) {
        setState(() {
          _records = filteredRecords;
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
      final fileName = 'rentabilidad_global_${DateFormat('yyyy-MM-dd').format(_fromDate!)}_${DateFormat('yyyy-MM-dd').format(_toDate!)}.xlsx';
      await ExcelExportUtils.exportProfitabilityRecords(
        records: _records,
        fileName: fileName,
        title: 'Rentabilidad Global',
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

  List<ProfitabilityRecordEntity> get _filteredRecords {
    return _records;
  }

  @override
  Widget build(BuildContext context) {
    final totalIncome = _records.where((r) => r.isIncome).fold<double>(0, (sum, r) => sum + r.amount);
    final totalTripExpenses = _records.where((r) => r.isTripExpense).fold<double>(0, (sum, r) => sum + r.amount);
    final totalMaintenanceExpenses = _records.where((r) => r.isMaintenanceExpense).fold<double>(0, (sum, r) => sum + r.amount);
    final balance = totalIncome - totalTripExpenses - totalMaintenanceExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentabilidad Global'),
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
                // Filtros adicionales
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterType,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por tipo',
                          prefixIcon: const Icon(Icons.filter_list),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todos')),
                          DropdownMenuItem(value: 'ingreso', child: Text('Ingresos')),
                          DropdownMenuItem(value: 'gasto_viaje', child: Text('Gastos Viaje')),
                          DropdownMenuItem(value: 'gasto_mantenimiento', child: Text('Gastos Mantenimiento')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Filtrar por vehículo',
                          prefixIcon: const Icon(Icons.directions_car),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _filterVehiclePlate = value.isEmpty ? null : value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Filtrar por cliente',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filterClientName = value.isEmpty ? null : value;
                    });
                  },
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
          // Resumen
          if (_records.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Ingresos', totalIncome, Colors.green),
                  _buildSummaryItem('G. Viaje', totalTripExpenses, Colors.orange),
                  _buildSummaryItem('G. Mant.', totalMaintenanceExpenses, Colors.red),
                  _buildSummaryItem('Balance', balance, balance >= 0 ? Colors.blue : Colors.red),
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
                              'No se encontraron registros',
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

  Widget _buildSummaryItem(String label, double amount, Color color) {
    final numberFormat = NumberFormat('#,###', 'es_CO');
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${numberFormat.format(amount.round())}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
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
            DataColumn(label: Text('Gastos Mant.')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Tipo Gasto')),
            DataColumn(label: Text('Ruta')),
            DataColumn(label: Text('Vehículo')),
          ],
          rows: _filteredRecords.map((record) {
            return DataRow(
              cells: [
                DataCell(Text(DateFormat('dd/MM/yyyy').format(record.date))),
                DataCell(
                  Chip(
                    label: Text(
                      record.isIncome
                          ? 'Ingreso'
                          : record.isTripExpense
                              ? 'G. Viaje'
                              : 'G. Mant.',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: record.isIncome
                        ? Colors.green.withOpacity(0.2)
                        : record.isTripExpense
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
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
                DataCell(Text(
                  record.isMaintenanceExpense ? '\$${numberFormat.format(record.amount)}' : '-',
                  style: TextStyle(
                    color: record.isMaintenanceExpense ? Colors.red : Colors.grey,
                    fontWeight: record.isMaintenanceExpense ? FontWeight.bold : FontWeight.normal,
                  ),
                )),
                DataCell(Text(record.clientName ?? '-')),
                DataCell(Text(record.expenseType ?? '-')),
                DataCell(Text(
                  record.routeOrigin != null && record.routeDestination != null
                      ? '${record.routeOrigin} → ${record.routeDestination}'
                      : '-',
                )),
                DataCell(Text(record.vehiclePlate ?? '-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

