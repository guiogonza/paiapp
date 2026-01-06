# Configuración de Permisos y Google Maps API Key

## ✅ Configuración Completada

### Android (`android/app/src/main/AndroidManifest.xml`)

#### Permisos de Ubicación:
- ✅ `ACCESS_FINE_LOCATION` - Ubicación precisa
- ✅ `ACCESS_COARSE_LOCATION` - Ubicación aproximada
- ✅ `FOREGROUND_SERVICE` - Servicio en primer plano (Android 14+)
- ✅ `FOREGROUND_SERVICE_LOCATION` - Ubicación en primer plano (Android 14+)
- ✅ `INTERNET` - Conexión a internet

#### Google Maps API Key:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

**⚠️ ACCIÓN REQUERIDA:** Reemplaza `YOUR_GOOGLE_MAPS_API_KEY` con tu API Key real.

---

### iOS (`ios/Runner/Info.plist`)

#### Permisos de Ubicación:
- ✅ `NSLocationWhenInUseUsageDescription` - Ubicación cuando la app está en uso
- ✅ `NSLocationAlwaysUsageDescription` - Ubicación siempre (background)
- ✅ `NSLocationAlwaysAndWhenInUseUsageDescription` - Ubicación siempre y cuando está en uso

#### Descripciones configuradas:
Todas las descripciones están configuradas con mensajes claros para el usuario.

---

### iOS (`ios/Runner/AppDelegate.swift`)

#### Google Maps SDK:
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

**⚠️ ACCIÓN REQUERIDA:** Reemplaza `YOUR_GOOGLE_MAPS_API_KEY` con tu API Key real.

---

## 📋 Pasos para Configurar Google Maps API Key

### 1. Obtener API Key de Google Maps

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuevo proyecto o selecciona uno existente
3. Habilita las siguientes APIs:
   - **Maps SDK for Android** (para Android)
   - **Maps SDK for iOS** (para iOS)
4. Ve a "Credenciales" → "Crear credenciales" → "Clave de API"
5. Copia tu API Key

### 2. Configurar en Android

Edita `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="TU_API_KEY_AQUI" />
```

### 3. Configurar en iOS

Edita `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("TU_API_KEY_AQUI")
```

### 4. (Opcional) Restringir API Key

Para producción, se recomienda restringir la API Key:
- **Restricción de aplicación Android:** Agrega el nombre del paquete (`com.example.pai_app`)
- **Restricción de aplicación iOS:** Agrega el Bundle ID de tu app
- **Restricción de API:** Solo permite "Maps SDK for Android" y "Maps SDK for iOS"

---

## 🔒 Permisos de Ubicación en Primer Plano

### Android 14+ (API 34+)

Los permisos `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_LOCATION` son **obligatorios** para usar ubicación en primer plano en Android 14+.

**Ya están configurados en el AndroidManifest.xml**

### iOS

Los permisos de ubicación en primer plano se manejan automáticamente cuando solicitas `NSLocationAlwaysAndWhenInUseUsageDescription`.

**Ya están configurados en Info.plist**

---

## ✅ Verificación

Después de configurar la API Key, verifica que:

1. ✅ Los permisos están en AndroidManifest.xml
2. ✅ Los permisos están en Info.plist
3. ✅ La API Key está configurada en AndroidManifest.xml
4. ✅ La API Key está configurada en AppDelegate.swift
5. ✅ Las APIs de Google Maps están habilitadas en Google Cloud Console

---

## 🚀 Próximos Pasos

1. Reemplaza `YOUR_GOOGLE_MAPS_API_KEY` en ambos archivos
2. Ejecuta `flutter pub get`
3. Para iOS: Ejecuta `cd ios && pod install` (si es necesario)
4. Compila y ejecuta la app

---

## 📝 Notas

- **Desarrollo:** Puedes usar la misma API Key para ambas plataformas
- **Producción:** Se recomienda usar API Keys separadas y restringirlas
- **Testing:** Asegúrate de probar en dispositivos reales para verificar los permisos


