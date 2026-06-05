# SmartPark

Detecta plazas de aparcamiento libres en Madrid mediante GPS anónimo.

## Requisitos

- Flutter 3.44+
- Dart 3.12+
- Xcode 16+ (solo para build iOS)
- Cuenta Apple Developer ($99/año) para firma de iOS

## Configuración

### 1. API Keys

Copia `.env.example` a `.env` y completa:

```
GOOGLE_MAPS_API_KEY=AIzaSy...
```

### 2. Firebase

1. Crea proyecto en https://console.firebase.google.com
2. Registra app Android (`com.example.smart_parking`)
3. Registra app iOS (`com.example.smart_parking`)
4. Descarga y agrega:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`
5. En Firebase Console:
   - **Authentication** > Sign-in method > Habilitar **Anonymous**
   - **Firestore** > Crear base de datos (modo prueba, región europea)

### 3. Google Maps

1. En https://console.cloud.google.com, habilita **Maps SDK for Android** y **Maps SDK for iOS**
2. Crea API Key y pégala en:
   - `android/app/src/main/AndroidManifest.xml` línea 20
   - `ios/Runner/AppDelegate.swift` línea 11

## Desarrollo local

```bash
flutter pub get
flutter run
```

## Build para iOS desde Windows (sin Mac)

### Opción A: Codemagic (recomendada)

1. Sube el proyecto a GitHub
2. Ve a https://codemagic.io/start/ y conecta tu repo
3. Codemagic detecta `codemagic.yaml` automáticamente
4. Agrega secrets en Codemagic:
   - `GOOGLE_MAPS_API_KEY`
   - `GOOGLE_SERVICES_JSON` (contenido de `google-services.json` en base64)
   - `GOOGLE_SERVICE_INFO_PLIST` (contenido de `GoogleService-Info.plist` en base64)
5. Conecta tu cuenta Apple Developer (certificados y provisioning profiles)
6. Ejecuta build → descarga el `.ipa`
7. Instala en tu iPhone con AltStore o SideStore

### Opción B: GitHub Actions

1. Sube el proyecto a GitHub
2. Ve a Settings > Secrets and variables > Actions y agrega:
   - `GOOGLE_MAPS_API_KEY`
   - `GOOGLE_SERVICES_JSON` (base64)
   - `GOOGLE_SERVICE_INFO_PLIST` (base64)
3. Ejecuta el workflow manualmente desde Actions tab
4. Descarga el artifact `.app` del workflow

### Opción C: Mac en la nube

```bash
# En MacStadium, MacinCloud o similar
git clone <tu-repo>
cd smart_parking
flutter pub get
flutter build ios --release
```

## Instalar .ipa en iPhone sin App Store

1. **AltStore**: https://altstore.io (Windows + iPhone, gratis)
2. **SideStore**: fork de AltStore, más estable
3. **Sideloadly**: https://sideloadly.io
4. Apple Configurator 2 (solo Mac)

## Estructura del proyecto

```
lib/
├── main.dart
├── config/app_config.dart
├── models/
│   ├── parking_spot.dart
│   └── anonymous_session.dart
├── services/
│   ├── location_service.dart
│   ├── parking_logic_service.dart
│   ├── firebase_service.dart
│   └── osm_service.dart
├── screens/map_screen.dart
└── widgets/
    ├── parking_marker.dart
    ├── legend_widget.dart
    └── info_panel.dart
```
