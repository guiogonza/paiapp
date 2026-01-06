# Resetear Contraseña del Super Admin

## ⚠️ Importante
**Las contraseñas en Supabase están hasheadas y NO se pueden ver en texto plano por seguridad.**

## Opciones para recuperar acceso:

### Opción 1: Resetear desde Supabase Dashboard (Recomendado)

1. Ve a **Supabase Dashboard** → **Authentication** → **Users**
2. Busca el usuario `pai@admin.com`
3. Haz clic en los **3 puntos** (⋮) al lado del usuario
4. Selecciona **"Reset Password"** o **"Send Password Reset Email"**
5. El usuario recibirá un email con un link para resetear la contraseña

### Opción 2: Resetear manualmente desde SQL (Solo si tienes acceso directo)

```sql
-- IMPORTANTE: Esto solo funciona si el usuario NO tiene email confirmado
-- O si quieres cambiar el email temporalmente

-- Ver el usuario actual
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users
WHERE email = 'pai@admin.com';

-- Si necesitas cambiar el email temporalmente (NO recomendado)
-- UPDATE auth.users
-- SET email = 'nuevo-email-temporal@admin.com'
-- WHERE email = 'pai@admin.com';
```

### Opción 3: Crear un nuevo usuario Super Admin temporal

```sql
-- Crear un nuevo usuario super_admin temporal
-- (Luego puedes eliminar este usuario cuando recuperes acceso al original)

-- 1. Primero crear el usuario en auth.users (esto se hace desde la app o desde Supabase Auth)
-- 2. Luego asignar el rol en profiles:

INSERT INTO public.profiles (id, email, role, full_name)
VALUES (
  gen_random_uuid(), -- O usar el ID del usuario de auth.users
  'admin-temp@pai.com',
  'super_admin',
  'Admin Temporal'
);

-- O actualizar un usuario existente:
UPDATE public.profiles
SET role = 'super_admin'
WHERE email = 'tu-email-temporal@admin.com';
```

### Opción 4: Usar la funcionalidad "Forgot Password" en la app

Si la app tiene implementada la funcionalidad de "Olvidé mi contraseña":
1. Ve a la pantalla de Login
2. Haz clic en "¿Olvidaste tu contraseña?"
3. Ingresa `pai@admin.com`
4. Revisa el email para el link de reset

## 🔐 Mejores Prácticas

1. **Guarda las contraseñas en un gestor de contraseñas** (1Password, LastPass, etc.)
2. **Usa contraseñas seguras** (mínimo 12 caracteres, mayúsculas, minúsculas, números, símbolos)
3. **No compartas contraseñas** por email o chat
4. **Usa autenticación de dos factores (2FA)** si está disponible

## 📝 Nota sobre Seguridad

Supabase almacena las contraseñas usando **bcrypt hashing**, que es unidireccional. Esto significa que:
- ✅ Es seguro: incluso los administradores de Supabase no pueden ver tu contraseña
- ❌ No se puede "desencriptar" o ver en texto plano
- ✅ La única forma de recuperar acceso es resetear la contraseña

