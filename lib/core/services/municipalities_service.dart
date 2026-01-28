import 'package:flutter/services.dart';

/// Servicio para cargar y buscar municipios de Colombia desde el archivo Excel
class MunicipalitiesService {
  static MunicipalitiesService? _instance;
  static MunicipalitiesService get instance {
    _instance ??= MunicipalitiesService._();
    return _instance!;
  }

  MunicipalitiesService._();

  List<String>? _municipalities;
  bool _isLoading = false;

  /// Normaliza un texto removiendo tildes y convirtiendo a minúsculas
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'a')
        .replaceAll('É', 'e')
        .replaceAll('Í', 'i')
        .replaceAll('Ó', 'o')
        .replaceAll('Ú', 'u')
        .replaceAll('Ñ', 'n');
  }

  /// Carga los municipios desde el archivo Excel en assets
  Future<List<String>> loadMunicipalities() async {
    print('📋 [MunicipalitiesService] loadMunicipalities() llamado');

    if (_municipalities != null) {
      print(
        '   ✅ Retornando ${_municipalities!.length} municipios desde caché',
      );
      return _municipalities!;
    }

    if (_isLoading) {
      print('   ⏳ Ya se está cargando, esperando...');
      // Esperar si ya se está cargando
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _municipalities ?? [];
    }

    _isLoading = true;
    print('   📂 Intentando cargar archivo CSV...');

    try {
      // Intentar cargar CSV primero (más simple y compatible)
      try {
        print('   📄 Leyendo: assets/Lists/municipios_colombia.csv');
        final csvData = await rootBundle.loadString(
          'assets/Lists/municipios_colombia.csv',
        );
        print(
          '   ✅ Archivo CSV leído correctamente (${csvData.length} caracteres)',
        );

        final lines = csvData.split('\n');
        print('   📊 Total de líneas en CSV: ${lines.length}');

        final municipalities = <String>[];

        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty &&
              trimmed.length > 1 &&
              !trimmed.toLowerCase().contains('municipio') &&
              !trimmed.toLowerCase().contains('nombre') &&
              !trimmed.toLowerCase().contains('ciudad') &&
              !municipalities.contains(trimmed)) {
            municipalities.add(trimmed);
          }
        }

        print(
          '   🏙️ Municipios válidos encontrados: ${municipalities.length}',
        );

        if (municipalities.isNotEmpty) {
          municipalities.sort();
          _municipalities = municipalities;
          print('✅ Cargados ${municipalities.length} municipios desde CSV');
          if (municipalities.isNotEmpty) {
            print(
              '   Primeros 5 municipios: ${municipalities.take(5).join(", ")}',
            );
          }
          _isLoading = false;
          return municipalities;
        } else {
          print('❌ No se encontraron municipios válidos en el CSV');
        }
      } catch (csvError) {
        print('⚠️ Error al leer CSV: $csvError');
        print('   Intentando leer Excel directamente...');
      }

      // Si CSV no funciona, intentar leer el Excel con un método alternativo
      // Por ahora, retornar lista vacía y mostrar instrucciones
      print(
        '❌ No se pudo cargar municipios. Por favor, convierte el archivo Excel a CSV:',
      );
      print('   1. Abre "Municipios Colombia.xls" en Excel o Google Sheets');
      print('   2. Exporta/Guarda como CSV (municipios_colombia.csv)');
      print('   3. Colócalo en assets/Lists/municipios_colombia.csv');
      print(
        '   4. Asegúrate de que solo tenga una columna con los nombres de los municipios',
      );

      _municipalities = [];
      _isLoading = false;
      return [];
    } catch (e, stackTrace) {
      print('❌ Error al cargar municipios desde Excel: $e');
      print('Stack trace: $stackTrace');
      _municipalities = [];
      return [];
    } finally {
      _isLoading = false;
    }
  }

  /// Busca municipios que coincidan con el texto de búsqueda
  /// La búsqueda es case-insensitive y sin tildes
  /// OPTIMIZADO: Prioriza coincidencias que empiezan con el query
  Future<List<String>> searchMunicipalities(String query) async {
    try {
      final allMunicipalities = await loadMunicipalities();

      if (query.trim().isEmpty) {
        return const [];
      }

      final normalizedQuery = _normalize(query.trim());

      // Separar resultados en 2 grupos: startsWith y contains
      final startsWithMatches = <String>[];
      final containsMatches = <String>[];

      for (final municipality in allMunicipalities) {
        final normalizedMunicipality = _normalize(municipality);

        if (normalizedMunicipality.startsWith(normalizedQuery)) {
          startsWithMatches.add(municipality);
        } else if (normalizedMunicipality.contains(normalizedQuery)) {
          containsMatches.add(municipality);
        }

        // Optimización: Detener si ya tenemos 50 resultados
        if (startsWithMatches.length + containsMatches.length >= 50) {
          break;
        }
      }

      // Combinar: primero los que empiezan, luego los que contienen
      final matches = [...startsWithMatches, ...containsMatches];

      // Limitar a 50 resultados
      final results = matches.length > 50 ? matches.take(50).toList() : matches;

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Verifica si un municipio existe en la lista
  Future<bool> municipalityExists(String municipality) async {
    final allMunicipalities = await loadMunicipalities();
    return allMunicipalities.contains(municipality);
  }

  /// Limpia la caché (útil para recargar después de actualizar el archivo)
  void clearCache() {
    _municipalities = null;
  }
}
