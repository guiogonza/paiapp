import 'package:flutter/material.dart';

/// Widget que dibuja el esquema de llantas de un vehículo dinámicamente
/// según su tipo y permite seleccionar una llanta específica
class TireSelector extends StatelessWidget {
  final String vehicleType; // 'turbo_sencillo', 'doble_troque', 'mini_mula_18', 'mula_22'
  final int? selectedTirePosition; // Posición de la llanta seleccionada (1-N)
  final Function(int) onTireSelected; // Callback cuando se selecciona una llanta

  const TireSelector({
    super.key,
    required this.vehicleType,
    this.selectedTirePosition,
    required this.onTireSelected,
  });

  /// Obtiene la configuración de llantas según el tipo de vehículo
  Map<String, dynamic> _getTireConfiguration() {
    switch (vehicleType) {
      case 'turbo_sencillo':
        return {
          'frontAxles': 1, // 1 eje delantero (2 llantas)
          'rearAxles': 1, // 1 eje trasero (4 llantas)
          'totalTires': 6,
        };
      case 'doble_troque':
        return {
          'frontAxles': 1, // 1 eje delantero (2 llantas)
          'rearAxles': 2, // 2 ejes traseros (4 llantas c/u)
          'totalTires': 10,
        };
      case 'mini_mula_18':
        return {
          'frontAxles': 1, // 1 eje delantero (2 llantas)
          'rearAxles': 4, // 4 ejes traseros (4 llantas c/u)
          'totalTires': 18,
        };
      case 'mula_22':
        return {
          'frontAxles': 1, // 1 eje delantero (2 llantas)
          'rearAxles': 5, // 5 ejes traseros (4 llantas c/u)
          'totalTires': 22,
        };
      default:
        return {
          'frontAxles': 0,
          'rearAxles': 0,
          'totalTires': 0,
        };
    }
  }

  /// Construye una llanta individual
  Widget _buildTire(int position, bool isSelected) {
    return GestureDetector(
      onTap: () => onTireSelected(position),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.black,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '$position',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  /// Construye el eje delantero (Tipo A)
  /// Estructura: [Llanta Izq] [SizedBox 40] [Llanta Der]
  /// Simula el espacio del motor/eje delantero
  Widget _buildFrontAxle(int leftPosition, int rightPosition) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTire(leftPosition, selectedTirePosition == leftPosition),
        const SizedBox(width: 40), // Espacio del motor/eje delantero
        _buildTire(rightPosition, selectedTirePosition == rightPosition),
      ],
    );
  }

  /// Construye un grupo doble de llantas (2 llantas juntas)
  /// Estructura: [Llanta Exterior] [SizedBox 4] [Llanta Interior]
  Widget _buildDoubleTireGroup(int exteriorPosition, int interiorPosition) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTire(exteriorPosition, selectedTirePosition == exteriorPosition),
        const SizedBox(width: 4), // Espacio pequeño entre llantas dobles
        _buildTire(interiorPosition, selectedTirePosition == interiorPosition),
      ],
    );
  }

  /// Construye un eje trasero (Tipo B)
  /// Estructura: [GrupoDobleIzq] [SizedBox 20] [GrupoDobleDer]
  /// Simula el espacio del diferencial/cardán
  /// Cada eje trasero tiene 4 llantas: 2 a la izquierda (exterior, interior) y 2 a la derecha (interior, exterior)
  Widget _buildRearAxle(int basePosition) {
    // basePosition: posición inicial del eje
    // Izquierda: exterior (basePosition), interior (basePosition + 1)
    // Derecha: interior (basePosition + 2), exterior (basePosition + 3)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Grupo doble izquierdo (exterior e interior)
        _buildDoubleTireGroup(basePosition, basePosition + 1),
        const SizedBox(width: 20), // Espacio del diferencial/cardán
        // Grupo doble derecho (interior y exterior)
        _buildDoubleTireGroup(basePosition + 2, basePosition + 3),
      ],
    );
  }

  /// Construye todos los ejes traseros
  Widget _buildAllRearAxles(int rearAxles, int startPosition) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rearAxles, (index) {
        final basePosition = startPosition + (index * 4);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRearAxle(basePosition),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _getTireConfiguration();

    if (config['totalTires'] == 0) {
      return const Center(
        child: Text(
          'Tipo de vehículo no válido',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Text(
            'Selecciona la posición de la llanta',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          // Esquema del chasis visto desde abajo
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eje delantero (Tipo A)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Delantero',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFrontAxle(1, 2), // Posiciones 1 y 2
              const SizedBox(height: 20),
              
              // Ejes traseros (Tipo B)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Traseros',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildAllRearAxles(
                config['rearAxles'] as int,
                3, // Empiezan en posición 3 (después del eje delantero)
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Sin seleccionar'),
              const SizedBox(width: 24),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Seleccionada'),
            ],
          ),
        ],
      ),
    );
  }
}

