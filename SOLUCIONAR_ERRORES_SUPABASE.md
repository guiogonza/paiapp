# Solución de Errores de Supabase

## Error: "Failed to fetch (api.supabase.com)"

Este error puede tener varias causas. Sigue estos pasos para solucionarlo:

### 1. Verificar que el proyecto de Supabase esté activo

1. Ve a https://supabase.com/dashboard
2. Verifica que tu proyecto esté activo (no pausado)
3. Si está pausado, reactívalo desde el dashboard

### 2. Verificar la URL y API Key

Asegúrate de que en `lib/main.dart` tengas las credenciales correctas:

```dart
await Supabase.initialize(
  url: 'https://urlbbkpuaiugputhnsqx.supabase.co', // Tu URL de Supabase
  anonKey: 'tu_anon_key_aqui', // Tu anon key
);
```

**Para obtener tus credenciales:**
1. Ve a tu proyecto en Supabase Dashboard
2. Settings > API
3. Copia la "Project URL" y "anon public" key

### 3. Verificar CORS (solo para web)

Si estás ejecutando en web y tienes problemas de CORS:

1. Ve a Supabase Dashboard > Settings > API
2. En "CORS Configuration", asegúrate de que esté habilitado
3. Agrega tu dominio local si es necesario:
   - `http://localhost:port`
   - `http://127.0.0.1:port`

### 4. Verificar que la tabla existe

El error puede ser porque la tabla `vehicle_history` no existe:

1. Ve a Supabase Dashboard > Table Editor
2. Verifica que exista la tabla `vehicle_history`
3. Si no existe, ejecuta el script SQL en `CREAR_TABLA_VEHICLE_HISTORY.sql`

### 5. Verificar políticas RLS (Row Level Security)

1. Ve a Supabase Dashboard > Table Editor
2. Selecciona la tabla `vehicle_history`
3. Ve a la pestaña "Policies"
4. Verifica que existan estas políticas:
   - "Users can read vehicle history" (SELECT)
   - "Users can insert vehicle history" (INSERT)

Si no existen, ejecuta el script SQL completo en `CREAR_TABLA_VEHICLE_HISTORY.sql`

### 6. Verificar conexión a internet

- Asegúrate de tener conexión a internet estable
- Prueba acceder a https://supabase.com desde tu navegador
- Verifica que no haya firewall bloqueando las conexiones

### 7. Verificar autenticación

El historial requiere que el usuario esté autenticado:

1. Asegúrate de estar logueado en la app
2. Verifica que la sesión de Supabase esté activa

### 8. Probar conexión manualmente

Puedes probar la conexión ejecutando este código en la consola de Supabase SQL Editor:

```sql
SELECT COUNT(*) FROM vehicle_history;
```

Si esto funciona, el problema es en la app. Si no funciona, el problema es en Supabase.

## Error: "La tabla vehicle_history no existe"

**Solución:** Ejecuta el script SQL en `CREAR_TABLA_VEHICLE_HISTORY.sql` en el SQL Editor de Supabase.

## Error: "Error de permisos" o "RLS"

**Solución:** Verifica que las políticas RLS estén creadas correctamente. Ejecuta la parte de políticas del script SQL.

## Error: "NetworkError" o problemas de CORS en web

**Soluciones:**
1. Verifica la configuración de CORS en Supabase (paso 3 arriba)
2. Prueba ejecutar la app en un dispositivo móvil en lugar de web
3. Verifica que no haya extensiones del navegador bloqueando las peticiones

## Verificar estado del servicio Supabase

1. Ve a https://status.supabase.com
2. Verifica que todos los servicios estén operativos
3. Si hay problemas, espera a que se resuelvan

## Contactar soporte

Si nada de lo anterior funciona:
1. Verifica los logs en Supabase Dashboard > Logs
2. Contacta al soporte de Supabase con los detalles del error
3. Incluye el mensaje de error completo y los pasos que seguiste

