# Configuración de Supabase para Autenticación

## Quitar Restricción de Contraseña Mínima

Para permitir contraseñas cortas (como "2023"), necesitas configurar Supabase desde el dashboard:

1. **Accede al Dashboard de Supabase:**
   - Ve a: https://supabase.com/dashboard
   - Selecciona tu proyecto: `urlbbkpuaiugputhnsqx`

2. **Configuración de Autenticación:**
   - Ve a: **Authentication** → **Settings** → **Password**
   - Busca la opción **"Minimum password length"**
   - Cambia el valor de `6` a `1` (o el mínimo que necesites)
   - Guarda los cambios

3. **Configuración de Políticas de Contraseña (Opcional):**
   - También puedes desactivar otras restricciones como:
     - Requerir mayúsculas
     - Requerir números
     - Requerir caracteres especiales

## Crear Usuario de Pruebas en Supabase

El código ahora crea automáticamente el usuario en Supabase cuando se valida exitosamente contra el API de GPS. Sin embargo, si quieres crearlo manualmente:

1. **Desde el Dashboard:**
   - Ve a: **Authentication** → **Users**
   - Click en **"Add user"** o **"Invite user"**
   - Email: `luisr@rastrear.com.co`
   - Password: `2023`
   - Marca **"Auto Confirm User"** para que no requiera confirmación de email

2. **O desde SQL Editor:**
   ```sql
   -- Crear usuario directamente (requiere permisos de admin)
   -- Nota: Esto crea el usuario pero necesitarás establecer la contraseña desde el dashboard
   ```

## Flujo de Autenticación Actual

1. **Login:**
   - Primero valida contra el API de GPS (`http://178.63.27.106/api/login`)
   - Si es exitoso, obtiene el `user_api_hash`
   - Luego intenta hacer login en Supabase
   - Si el usuario no existe en Supabase, lo crea automáticamente
   - Si existe, simplemente hace login

2. **Registro:**
   - Primero valida contra el API de GPS
   - Si es exitoso, crea el usuario en Supabase

3. **Logout:**
   - Cierra sesión en Supabase
   - Limpia el API key del GPS guardado localmente

## Notas Importantes

- **Restricción de Contraseña:** Si Supabase sigue rechazando contraseñas cortas después de cambiar la configuración, puede ser que necesites esperar unos minutos para que los cambios se apliquen, o verificar que no haya políticas adicionales configuradas.

- **Confirmación de Email:** El código está configurado para no requerir confirmación de email (`emailRedirectTo: null`), pero esto puede variar según la configuración de tu proyecto Supabase.

- **Usuario de Pruebas:** El usuario `luisr@rastrear.com.co` con contraseña `2023` se creará automáticamente la primera vez que hagas login exitoso contra el API de GPS.


