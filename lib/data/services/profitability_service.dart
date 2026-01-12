import 'package:pai_app/data/repositories/trip_repository_impl.dart';
import 'package:pai_app/data/repositories/expense_repository_impl.dart';
import 'package:pai_app/data/repositories/maintenance_repository_impl.dart';
import 'package:pai_app/data/repositories/vehicle_repository_impl.dart';
import 'package:pai_app/data/repositories/profile_repository_impl.dart';
import 'package:pai_app/domain/entities/profitability_record_entity.dart';
import 'package:pai_app/domain/entities/trip_entity.dart';
import 'package:pai_app/domain/entities/expense_entity.dart';
import 'package:pai_app/domain/entities/vehicle_entity.dart';

/// Servicio para obtener datos consolidados de rentabilidad
class ProfitabilityService {
  final _tripRepository = TripRepositoryImpl();
  final _expenseRepository = ExpenseRepositoryImpl();
  final _maintenanceRepository = MaintenanceRepositoryImpl();
  final _vehicleRepository = VehicleRepositoryImpl();
  final _profileRepository = ProfileRepositoryImpl();

  /// Obtiene registros de rentabilidad por vehículo en un rango de fechas
  Future<List<ProfitabilityRecordEntity>> getRecordsByVehicle({
    required String vehicleId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final records = <ProfitabilityRecordEntity>[];

    // Obtener vehículo para la placa
    final vehiclesResult = await _vehicleRepository.getVehicles();
    final vehicle = vehiclesResult.fold(
      (failure) => null,
      (vehicles) => vehicles.firstWhere(
        (v) => v.id == vehicleId,
        orElse: () => vehicles.first,
      ),
    );

    // 1. Ingresos (viajes)
    final tripsResult = await _tripRepository.getTrips();
    tripsResult.fold(
      (failure) => null,
      (trips) {
        for (var trip in trips) {
          if (trip.vehicleId == vehicleId &&
              trip.startDate != null &&
              trip.startDate!.isAfter(fromDate.subtract(const Duration(days: 1))) &&
              trip.startDate!.isBefore(toDate.add(const Duration(days: 1))) &&
              trip.revenueAmount > 0) {
            records.add(ProfitabilityRecordEntity(
              id: 'trip_${trip.id ?? ''}',
              date: trip.startDate!,
              type: 'ingreso',
              amount: trip.revenueAmount,
              clientName: trip.clientName, // Cliente del viaje
              routeOrigin: trip.origin,
              routeDestination: trip.destination,
              vehicleId: vehicleId,
              vehiclePlate: vehicle?.placa,
              driverId: null,
              driverName: trip.driverName,
              tripId: trip.id,
            ));
          }
        }
      },
    );

    // 2. Gastos de viaje
    final expensesResult = await _expenseRepository.getExpenses();
    final expenses = expensesResult.fold(
      (failure) => <ExpenseEntity>[],
      (expenses) => expenses,
    );
    
    for (var expense in expenses) {
      if (expense.tripId.isNotEmpty) {
        // Obtener el viaje para verificar el vehículo
        final tripResult = await _tripRepository.getTripById(expense.tripId);
        tripResult.fold(
          (failure) => null,
          (trip) {
            if (trip.vehicleId == vehicleId &&
                expense.date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
                expense.date.isBefore(toDate.add(const Duration(days: 1)))) {
              records.add(ProfitabilityRecordEntity(
                id: 'expense_${expense.id ?? ''}',
                date: expense.date,
                type: 'gasto_viaje',
                amount: expense.amount,
                clientName: trip.clientName, // Cliente del viaje relacionado
                expenseType: expense.type, // Usar 'type' en lugar de 'category'
                routeOrigin: trip.origin,
                routeDestination: trip.destination,
                vehicleId: vehicleId,
                vehiclePlate: vehicle?.placa,
                driverId: expense.driverId,
                driverName: null,
                tripId: expense.tripId,
              ));
            }
          },
        );
      }
    }

    // 3. Gastos de mantenimiento
    final maintenanceResult = await _maintenanceRepository.getAllMaintenance();
    maintenanceResult.fold(
      (failure) => null,
      (maintenanceList) {
        for (var maintenance in maintenanceList) {
          if (maintenance.vehicleId == vehicleId &&
              maintenance.serviceDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
              maintenance.serviceDate.isBefore(toDate.add(const Duration(days: 1)))) {
            records.add(ProfitabilityRecordEntity(
              id: 'maintenance_${maintenance.id ?? ''}',
              date: maintenance.serviceDate,
              type: 'gasto_mantenimiento',
              amount: maintenance.cost,
              clientName: null, // Mantenimiento no tiene cliente
              expenseType: maintenance.serviceType,
              routeOrigin: null, // Mantenimiento no tiene ruta
              routeDestination: null,
              vehicleId: vehicleId,
              vehiclePlate: vehicle?.placa,
              driverId: null,
              driverName: null,
              tripId: null,
            ));
          }
        }
      },
    );

    // Ordenar por fecha
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  /// Obtiene registros de rentabilidad por ruta (origen-destino) en un rango de fechas
  Future<List<ProfitabilityRecordEntity>> getRecordsByRoute({
    required String origin,
    required String destination,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final records = <ProfitabilityRecordEntity>[];

    // Obtener vehículos primero
    final vehiclesResult = await _vehicleRepository.getVehicles();
    final vehicles = vehiclesResult.fold(
      (failure) => <VehicleEntity>[],
      (vehicles) => vehicles,
    );

    // 1. Ingresos (viajes con esa ruta)
    final tripsResult = await _tripRepository.getTrips();
    tripsResult.fold(
      (failure) => null,
      (trips) {
        for (var trip in trips) {
          if (trip.origin.toLowerCase().contains(origin.toLowerCase()) &&
              trip.destination.toLowerCase().contains(destination.toLowerCase()) &&
              trip.startDate != null &&
              trip.startDate!.isAfter(fromDate.subtract(const Duration(days: 1))) &&
              trip.startDate!.isBefore(toDate.add(const Duration(days: 1))) &&
              trip.revenueAmount > 0) {
            // Obtener vehículo
            final vehicle = vehicles.firstWhere(
              (v) => v.id == trip.vehicleId,
              orElse: () => vehicles.isNotEmpty ? vehicles.first : VehicleEntity(
                placa: '',
                marca: '',
                modelo: '',
                ano: 0,
              ),
            );

            records.add(ProfitabilityRecordEntity(
              id: 'trip_${trip.id ?? ''}',
              date: trip.startDate!,
              type: 'ingreso',
              amount: trip.revenueAmount,
              clientName: trip.clientName,
              routeOrigin: trip.origin,
              routeDestination: trip.destination,
              vehicleId: trip.vehicleId,
              vehiclePlate: vehicle.placa,
              driverId: null,
              driverName: trip.driverName,
              tripId: trip.id,
            ));
          }
        }
      },
    );

    // 2. Gastos de viaje (solo gastos relacionados con viajes de esa ruta)
    final expensesResult = await _expenseRepository.getExpenses();
    final expenses = expensesResult.fold(
      (failure) => <ExpenseEntity>[],
      (expenses) => expenses,
    );
    
    for (var expense in expenses) {
      if (expense.tripId.isNotEmpty) {
        final tripResult = await _tripRepository.getTripById(expense.tripId);
        tripResult.fold(
          (failure) => null,
          (trip) {
            if (trip.origin.toLowerCase().contains(origin.toLowerCase()) &&
                trip.destination.toLowerCase().contains(destination.toLowerCase()) &&
                expense.date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
                expense.date.isBefore(toDate.add(const Duration(days: 1)))) {
              final vehicle = vehicles.firstWhere(
                (v) => v.id == trip.vehicleId,
                orElse: () => vehicles.isNotEmpty ? vehicles.first : VehicleEntity(
                  placa: '',
                  marca: '',
                  modelo: '',
                  ano: 0,
                ),
              );

              records.add(ProfitabilityRecordEntity(
                id: 'expense_${expense.id ?? ''}',
                date: expense.date,
                type: 'gasto_viaje',
                amount: expense.amount,
                clientName: trip.clientName,
                expenseType: expense.type, // Usar 'type' en lugar de 'category'
                routeOrigin: trip.origin,
                routeDestination: trip.destination,
                vehicleId: trip.vehicleId,
                vehiclePlate: vehicle.placa,
                driverId: expense.driverId,
                driverName: null,
                tripId: expense.tripId,
              ));
            }
          },
        );
      }
    }

    // Ordenar por fecha
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  /// Obtiene registros de rentabilidad por conductor en un rango de fechas
  Future<List<ProfitabilityRecordEntity>> getRecordsByDriver({
    required String driverId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final records = <ProfitabilityRecordEntity>[];

    // Obtener perfil del conductor para obtener email y nombre
    final driverProfileResult = await _profileRepository.getProfileByUserId(driverId);
    final driverEmail = driverProfileResult.fold(
      (failure) => null,
      (profile) => profile.email,
    );
    final driverName = driverProfileResult.fold(
      (failure) => null,
      (profile) => profile.email?.split('@').first, // Usar parte antes del @ como nombre alternativo
    );
    
    // Obtener todos los vehículos para buscar placas
    final vehiclesResult = await _vehicleRepository.getVehicles();
    final allVehicles = vehiclesResult.fold(
      (failure) => <VehicleEntity>[],
      (vehicles) => vehicles,
    );
    final vehiclesMap = {for (var v in allVehicles) v.id ?? '': v};
    
    // Obtener vehículos asignados al conductor (opcional, para mantenimiento)
    final assignedVehicles = allVehicles.where((v) {
      if (driverEmail == null) return false;
      return v.conductor == driverEmail || 
             v.conductor == driverId ||
             (driverName != null && v.conductor?.toLowerCase().contains(driverName.toLowerCase()) == true);
    }).toList();
    
    final vehicleIds = assignedVehicles.map((v) => v.id).whereType<String>().toList();

    // 1. Ingresos (viajes donde driver_name coincide con el conductor)
    final tripsResult = await _tripRepository.getTrips();
    tripsResult.fold(
      (failure) => null,
      (trips) {
        for (var trip in trips) {
          // Buscar por driver_name que puede ser email o nombre
          final matchesDriver = driverEmail != null && 
              (trip.driverName.toLowerCase() == driverEmail.toLowerCase() ||
               trip.driverName.toLowerCase().contains(driverEmail.toLowerCase().split('@').first) ||
               (driverName != null && trip.driverName.toLowerCase().contains(driverName.toLowerCase())));
          
          if (matchesDriver &&
              trip.startDate != null &&
              trip.startDate!.isAfter(fromDate.subtract(const Duration(days: 1))) &&
              trip.startDate!.isBefore(toDate.add(const Duration(days: 1))) &&
              trip.revenueAmount > 0) {
            final vehicle = vehiclesMap[trip.vehicleId];

            records.add(ProfitabilityRecordEntity(
              id: 'trip_${trip.id ?? ''}',
              date: trip.startDate!,
              type: 'ingreso',
              amount: trip.revenueAmount,
              clientName: trip.clientName,
              routeOrigin: trip.origin,
              routeDestination: trip.destination,
              vehicleId: trip.vehicleId,
              vehiclePlate: vehicle?.placa ?? '',
              driverId: driverId,
              driverName: trip.driverName,
              tripId: trip.id,
            ));
          }
        }
      },
    );

    // 2. Gastos de viaje (donde driverId coincide O el viaje tiene el driver_name del conductor)
    final expensesResult = await _expenseRepository.getExpenses();
    final expenses = expensesResult.fold(
      (failure) => <ExpenseEntity>[],
      (expenses) => expenses,
    );
    
    for (var expense in expenses) {
      if (expense.tripId.isNotEmpty &&
          expense.date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(toDate.add(const Duration(days: 1)))) {
        final tripResult = await _tripRepository.getTripById(expense.tripId);
        tripResult.fold(
          (failure) => null,
          (trip) {
            // Verificar si el gasto pertenece al conductor (por driverId o por driver_name del viaje)
            final expenseBelongsToDriver = expense.driverId == driverId;
            final tripBelongsToDriver = driverEmail != null && 
                (trip.driverName.toLowerCase() == driverEmail.toLowerCase() ||
                 trip.driverName.toLowerCase().contains(driverEmail.toLowerCase().split('@').first) ||
                 (driverName != null && trip.driverName.toLowerCase().contains(driverName.toLowerCase())));
            
            if (expenseBelongsToDriver || tripBelongsToDriver) {
              final vehicle = vehiclesMap[trip.vehicleId];

              records.add(ProfitabilityRecordEntity(
                id: 'expense_${expense.id ?? ''}',
                date: expense.date,
                type: 'gasto_viaje',
                amount: expense.amount,
                clientName: trip.clientName,
                expenseType: expense.type,
                routeOrigin: trip.origin,
                routeDestination: trip.destination,
                vehicleId: trip.vehicleId,
                vehiclePlate: vehicle?.placa ?? '',
                driverId: driverId,
                driverName: null,
                tripId: expense.tripId,
              ));
            }
          },
        );
      }
    }

    // 3. Gastos de mantenimiento (de vehículos asignados)
    final maintenanceResult = await _maintenanceRepository.getAllMaintenance();
    maintenanceResult.fold(
      (failure) => null,
      (maintenanceList) {
        for (var maintenance in maintenanceList) {
          if (vehicleIds.contains(maintenance.vehicleId) &&
              maintenance.serviceDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
              maintenance.serviceDate.isBefore(toDate.add(const Duration(days: 1)))) {
            final vehicle = assignedVehicles.firstWhere(
              (v) => v.id == maintenance.vehicleId,
              orElse: () => assignedVehicles.first,
            );

            records.add(ProfitabilityRecordEntity(
              id: 'maintenance_${maintenance.id ?? ''}',
              date: maintenance.serviceDate,
              type: 'gasto_mantenimiento',
              amount: maintenance.cost,
              clientName: null,
              expenseType: maintenance.serviceType,
              routeOrigin: null,
              routeDestination: null,
              vehicleId: maintenance.vehicleId,
              vehiclePlate: vehicle.placa,
              driverId: driverId,
              driverName: null,
              tripId: null,
            ));
          }
        }
      },
    );

    // Ordenar por fecha
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  /// Obtiene todos los registros de rentabilidad global en un rango de fechas
  Future<List<ProfitabilityRecordEntity>> getGlobalRecords({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final records = <ProfitabilityRecordEntity>[];

    // Obtener todos los vehículos
    final vehiclesResult = await _vehicleRepository.getVehicles();
    final vehicles = vehiclesResult.fold(
      (failure) => <VehicleEntity>[],
      (v) => v,
    );
    final vehiclesMap = {for (var v in vehicles) v.id ?? '': v};

    // 1. Ingresos (todos los viajes)
    final tripsResult = await _tripRepository.getTrips();
    tripsResult.fold(
      (failure) => null,
      (trips) {
        for (var trip in trips) {
          if (trip.startDate != null &&
              trip.startDate!.isAfter(fromDate.subtract(const Duration(days: 1))) &&
              trip.startDate!.isBefore(toDate.add(const Duration(days: 1))) &&
              trip.revenueAmount > 0) {
            final vehicle = vehiclesMap[trip.vehicleId];

            records.add(ProfitabilityRecordEntity(
              id: 'trip_${trip.id ?? ''}',
              date: trip.startDate!,
              type: 'ingreso',
              amount: trip.revenueAmount,
              clientName: null,
              routeOrigin: trip.origin,
              routeDestination: trip.destination,
              vehicleId: trip.vehicleId,
              vehiclePlate: vehicle?.placa,
              driverId: null,
              driverName: trip.driverName,
              tripId: trip.id,
            ));
          }
        }
      },
    );

    // 2. Gastos de viaje (todos)
    final expensesResult = await _expenseRepository.getExpenses();
    final expenses = expensesResult.fold(
      (failure) => <ExpenseEntity>[],
      (expenses) => expenses,
    );
    
    for (var expense in expenses) {
      if (expense.date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(toDate.add(const Duration(days: 1)))) {
        TripEntity? trip;
        if (expense.tripId.isNotEmpty) {
          final tripResult = await _tripRepository.getTripById(expense.tripId);
          tripResult.fold(
            (failure) => null,
            (t) => trip = t,
          );
        }

        VehicleEntity? vehicle;
        final currentTrip = trip;
        if (currentTrip != null && currentTrip.vehicleId.isNotEmpty) {
          vehicle = vehiclesMap[currentTrip.vehicleId];
        }

        records.add(ProfitabilityRecordEntity(
          id: 'expense_${expense.id ?? ''}',
          date: expense.date,
          type: 'gasto_viaje',
          amount: expense.amount,
          clientName: trip?.clientName,
          expenseType: expense.type, // Usar 'type' en lugar de 'category'
          routeOrigin: trip?.origin,
          routeDestination: trip?.destination,
          vehicleId: trip?.vehicleId,
          vehiclePlate: vehicle?.placa,
          driverId: expense.driverId,
          driverName: null,
          tripId: expense.tripId,
        ));
      }
    }

    // 3. Gastos de mantenimiento (todos)
    final maintenanceResult = await _maintenanceRepository.getAllMaintenance();
    maintenanceResult.fold(
      (failure) => null,
      (maintenanceList) {
        for (var maintenance in maintenanceList) {
          if (maintenance.serviceDate.isAfter(fromDate.subtract(const Duration(days: 1))) &&
              maintenance.serviceDate.isBefore(toDate.add(const Duration(days: 1)))) {
            final vehicle = vehiclesMap[maintenance.vehicleId];

            records.add(ProfitabilityRecordEntity(
              id: 'maintenance_${maintenance.id ?? ''}',
              date: maintenance.serviceDate,
              type: 'gasto_mantenimiento',
              amount: maintenance.cost,
              clientName: null,
              expenseType: maintenance.serviceType,
              routeOrigin: null,
              routeDestination: null,
              vehicleId: maintenance.vehicleId,
              vehiclePlate: vehicle?.placa,
              driverId: null,
              driverName: null,
              tripId: null,
            ));
          }
        }
      },
    );

    // Ordenar por fecha
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }
}

