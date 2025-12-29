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
    if (_municipalities != null) {
      return _municipalities!;
    }

    if (_isLoading) {
      // Esperar si ya se está cargando
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _municipalities ?? [];
    }

    _isLoading = true;

    try {
      // Intentar cargar CSV primero (más simple y compatible)
      try {
        final csvData = await rootBundle.loadString('assets/Lists/municipios_colombia.csv');
        final lines = csvData.split('\n');
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
        
        if (municipalities.isNotEmpty) {
          municipalities.sort();
          _municipalities = municipalities;
          print('✅ Cargados ${municipalities.length} municipios desde CSV');
          if (municipalities.isNotEmpty) {
            print('   Primeros 5 municipios: ${municipalities.take(5).join(", ")}');
          }
          _isLoading = false;
          return municipalities;
        }
      } catch (csvError) {
        print('⚠️ No se encontró CSV, intentando leer Excel directamente...');
        print('   Error CSV: $csvError');
      }
      
      // Si CSV no funciona, intentar leer el Excel con un método alternativo
      // Por ahora, retornar lista vacía y mostrar instrucciones
      print('❌ No se pudo cargar municipios. Por favor, convierte el archivo Excel a CSV:');
      print('   1. Abre "Municipios Colombia.xls" en Excel o Google Sheets');
      print('   2. Exporta/Guarda como CSV (municipios_colombia.csv)');
      print('   3. Colócalo en assets/Lists/municipios_colombia.csv');
      print('   4. Asegúrate de que solo tenga una columna con los nombres de los municipios');
      
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
  Future<List<String>> searchMunicipalities(String query) async {
    try {
      final allMunicipalities = await loadMunicipalities();
      
      if (query.trim().isEmpty) {
        // Si está vacío, no mostrar nada (mejor UX)
        return const [];
      }

      final normalizedQuery = _normalize(query.trim());
      print('🔍 Buscando municipios con query: "$query" (normalizado: "$normalizedQuery")');
      print('   Total de municipios disponibles: ${allMunicipalities.length}');
      
      // Filtrar municipios que contengan el texto normalizado
      final matches = allMunicipalities
          .where((municipality) {
            final normalizedMunicipality = _normalize(municipality);
            return normalizedMunicipality.contains(normalizedQuery);
          })
          .toList();
      
      print('   Encontrados ${matches.length} municipios que coinciden');
      if (matches.isNotEmpty && matches.length <= 5) {
        print('   Resultados: ${matches.join(", ")}');
      }
      
      // Limitar a 20 resultados para mejor rendimiento
      return matches.length > 20 ? matches.take(20).toList() : matches;
    } catch (e, stackTrace) {
      print('❌ Error al buscar municipios: $e');
      print('Stack trace: $stackTrace');
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

