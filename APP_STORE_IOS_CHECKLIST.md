# Publicacion iOS - Taxi Seguro

Configuracion ya preparada en el proyecto:

- Bundle ID iOS: `com.taxiseguro.app`
- Nombre visible: `Taxi Seguro`
- Version Flutter tomada desde `pubspec.yaml`
- App icons iOS cargados
- Permiso de ubicacion ajustado a uso en primer plano
- Integracion lista para Google Maps con `GMS_API_KEY` en los `.xcconfig`
- `Podfile` agregado para instalar dependencias iOS correctamente
- Deployment target iOS subido a `14.0` por compatibilidad con `google_maps_flutter_ios`

Lo unico que falta completar antes de subir desde una Mac:

1. Abrir `ios/Runner.xcworkspace` en Xcode.
2. En `Signing & Capabilities`, seleccionar tu equipo de Apple Developer.
3. Definir el valor real de `GMS_API_KEY` en:
   - `ios/Flutter/Debug.xcconfig`
   - `ios/Flutter/Release.xcconfig`
4. Ejecutar:
   - `flutter pub get`
   - `cd ios && pod install`
   - `flutter build ipa`
5. En App Store Connect completar:
   - screenshots
   - descripcion y palabras clave
   - politica de privacidad URL
   - cuestionario de privacidad
   - categoria de la app

Notas:

- Si no van a rastrear ubicacion en segundo plano, no activen `Background Modes > Location updates`.
- Si usan otro nombre comercial final, cambien `CFBundleDisplayName` en `ios/Runner/Info.plist`.
