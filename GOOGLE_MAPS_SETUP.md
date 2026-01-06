# Configuración de Google Maps

Para que el mapa funcione correctamente, necesitas configurar tu API Key de Google Maps.

## Pasos para obtener tu API Key:

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuevo proyecto o selecciona uno existente
3. Habilita la **Maps SDK for Android** y **Maps SDK for iOS**
4. Crea credenciales (API Key)
5. Restringe la API Key a tu aplicación (recomendado para producción)

## Configuración en Android:

1. Abre `android/app/src/main/AndroidManifest.xml`
2. Busca la línea con `YOUR_GOOGLE_MAPS_API_KEY`
3. Reemplázala con tu API Key real:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="TU_API_KEY_AQUI" />
   ```

## Configuración en iOS:

1. Abre `ios/Runner/AppDelegate.swift`
2. Busca la línea con `YOUR_GOOGLE_MAPS_API_KEY`
3. Reemplázala con tu API Key real:
   ```swift
   GMSServices.provideAPIKey("TU_API_KEY_AQUI")
   ```

## Nota:

- Para desarrollo, puedes usar la misma API Key en ambas plataformas
- Para producción, se recomienda crear API Keys separadas y restringirlas
- Asegúrate de habilitar las APIs necesarias en Google Cloud Console


