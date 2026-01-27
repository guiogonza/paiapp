# PAI App - Infraestructura Local con PostgreSQL

## Descripción
Esta configuración reemplaza completamente a Supabase con una infraestructura local:

- **PostgreSQL 15**: Base de datos principal con persistencia
- **API Node.js**: Servidor REST con autenticación JWT
- **Flutter Web**: Aplicación frontend

## Estructura

```
pai_app/
├── api/                    # API REST Node.js
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── database/               # Scripts SQL
│   └── init.sql           # Creación de tablas
├── docker-compose.local.yml # Orquestación de servicios
└── lib/data/services/
    └── local_api_client.dart # Cliente Flutter
```

## Tablas de Base de Datos

| Tabla | Descripción |
|-------|-------------|
| `profiles` | Usuarios (admin, owner, driver) |
| `vehicles` | Vehículos registrados |
| `vehicle_history` | Historial de ubicaciones GPS |
| `documents` | Documentos de vehículos |
| `trips` | Viajes/recorridos |
| `expenses` | Gastos |
| `maintenance` | Mantenimientos |
| `remisiones` | Documentos de envío |
| `gps_credentials` | Credenciales del sistema GPS |

## Despliegue

### 1. Subir archivos al servidor
```bash
git add -A
git commit -m "feat: infraestructura local con PostgreSQL"
git push origin main
```

### 2. En el servidor (VPS)
```bash
cd /root/paiapp
git pull origin main

# Construir la API
docker build -t pai-api ./api

# Construir la app Flutter
docker build -t pai-app .

# Iniciar todos los servicios
docker compose -f docker-compose.local.yml up -d
```

### 3. Verificar servicios
```bash
# Ver contenedores
docker ps

# Ver logs
docker logs pai-postgres
docker logs pai-api
docker logs pai-app

# Probar API
curl http://localhost:3000/health
```

## Endpoints de la API

### Autenticación
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/auth/login` | Login |
| POST | `/auth/signup` | Registro |
| GET | `/auth/user` | Usuario actual |

### Recursos (requieren autenticación)
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET/POST | `/rest/v1/profiles` | Perfiles/Conductores |
| GET/POST | `/rest/v1/vehicles` | Vehículos |
| GET/POST | `/rest/v1/vehicle_history` | Historial GPS |
| GET/POST | `/rest/v1/documents` | Documentos |
| GET/POST | `/rest/v1/trips` | Viajes |
| GET/POST | `/rest/v1/expenses` | Gastos |
| GET | `/rest/v1/maintenance` | Mantenimientos |

## Credenciales por Defecto

### Base de Datos
- **Host**: postgres (interno) / localhost:5432 (externo)
- **Database**: pai_database
- **User**: pai_admin
- **Password**: pai_secure_password_2026

### Usuarios Iniciales
| Email | Contraseña | Rol |
|-------|------------|-----|
| admin@conductor.app | admin123 | super_admin |
| jpcuartasv@gmail.com | owner123 | owner |

## Uso en Flutter

```dart
import 'package:pai_app/data/services/local_api_client.dart';

final api = LocalApiClient();

// Inicializar (cargar token guardado)
await api.initialize();

// Login
final result = await api.login('123456', 'password');

// Obtener vehículos
final vehicles = await api.getVehicles();

// Crear conductor
await api.createDriver(
  username: '987654',
  password: 'pass123',
  fullName: 'Juan Pérez',
  assignedVehicleId: 'vehicle-uuid',
);
```

## Persistencia de Datos

Los datos de PostgreSQL se guardan en un volumen Docker:
- **Volumen**: `postgres_data`
- **Ubicación**: `/var/lib/docker/volumes/paiapp_postgres_data/`

Para hacer backup:
```bash
docker exec pai-postgres pg_dump -U pai_admin pai_database > backup.sql
```

Para restaurar:
```bash
docker exec -i pai-postgres psql -U pai_admin pai_database < backup.sql
```

## Migración desde Supabase

1. Exportar datos de Supabase
2. Adaptar formato SQL si es necesario
3. Importar en PostgreSQL local

## Puertos

| Servicio | Puerto Interno | Puerto Externo |
|----------|----------------|----------------|
| PostgreSQL | 5432 | 5432 |
| API | 3000 | 3000 |
| Flutter App | 80 | 80 |
