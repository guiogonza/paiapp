import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pai_app/domain/entities/profitability_record_entity.dart';

class ExcelExportUtils {
  /// Exporta registros de rentabilidad a Excel
  static Future<void> exportProfitabilityRecords({
    required List<ProfitabilityRecordEntity> records,
    required String fileName,
    String? title,
  }) async {
    if (!kIsWeb) {
      throw Exception('La exportación a Excel solo está disponible en web');
    }

    // Crear un nuevo libro de Excel
    final excel = Excel.createExcel();
    
    // Renombrar Sheet1 (que se crea por defecto) a Rentabilidad
    excel.rename('Sheet1', 'Rentabilidad');
    
    // Obtener la hoja Rentabilidad
    final sheet = excel['Rentabilidad'];

    // Formato de fecha
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Título (si se proporciona)
    if (title != null) {
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue(title);
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Encabezados
    final headers = [
      'Fecha',
      'Tipo',
      'Ingresos',
      'Gastos Viaje',
      'Gastos Mantenimiento',
      'Cliente',
      'Tipo Gasto',
      'Ruta',
    ];

    int startRow = title != null ? 3 : 1;
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Datos
    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final rowIndex = startRow + 1 + i;

      // Fecha
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(dateFormat.format(record.date));

      // Tipo
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        record.isIncome
            ? 'Ingreso'
            : record.isTripExpense
                ? 'Gasto Viaje'
                : 'Gasto Mantenimiento',
      );

      // Ingresos
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = IntCellValue(
        record.isIncome ? record.amount.toInt() : 0,
      );

      // Gastos Viaje
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = IntCellValue(
        record.isTripExpense ? record.amount.toInt() : 0,
      );

      // Gastos Mantenimiento
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = IntCellValue(
        record.isMaintenanceExpense ? record.amount.toInt() : 0,
      );

      // Cliente
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(record.clientName ?? '-');

      // Tipo Gasto
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = TextCellValue(record.expenseType ?? '-');

      // Ruta
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = TextCellValue(
        record.routeOrigin != null && record.routeDestination != null
            ? '${record.routeOrigin} → ${record.routeDestination}'
            : '-',
      );
    }

    // Ajustar ancho de columnas
    sheet.setColumnWidth(0, 12); // Fecha
    sheet.setColumnWidth(1, 15); // Tipo
    sheet.setColumnWidth(2, 15); // Ingresos
    sheet.setColumnWidth(3, 15); // Gastos Viaje
    sheet.setColumnWidth(4, 18); // Gastos Mantenimiento
    sheet.setColumnWidth(5, 20); // Cliente
    sheet.setColumnWidth(6, 15); // Tipo Gasto
    sheet.setColumnWidth(7, 30); // Ruta

    // Totales
    final totalRow = startRow + 1 + records.length;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow))
        .value = TextCellValue('TOTALES');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow))
        .cellStyle = CellStyle(bold: true);

    final totalIncome = records.where((r) => r.isIncome).fold<double>(
          0,
          (sum, r) => sum + r.amount,
        );
    final totalTripExpenses = records.where((r) => r.isTripExpense).fold<double>(
          0,
          (sum, r) => sum + r.amount,
        );
    final totalMaintenanceExpenses = records.where((r) => r.isMaintenanceExpense).fold<double>(
          0,
          (sum, r) => sum + r.amount,
        );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: totalRow))
        .value = IntCellValue(totalIncome.toInt());
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow))
        .value = IntCellValue(totalTripExpenses.toInt());
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow))
        .value = IntCellValue(totalMaintenanceExpenses.toInt());

    // Balance
    final balanceRow = totalRow + 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: balanceRow))
        .value = TextCellValue('BALANCE');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: balanceRow))
        .cellStyle = CellStyle(bold: true);

    final balance = totalIncome - totalTripExpenses - totalMaintenanceExpenses;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: balanceRow))
        .value = IntCellValue(balance.toInt());
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: balanceRow))
        .cellStyle = CellStyle(
      bold: true,
    );

    // Convertir a bytes
    final excelBytes = excel.save();
    if (excelBytes == null) {
      throw Exception('Error al generar el archivo Excel');
    }

    // Descargar en web
    final blob = html.Blob([excelBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

