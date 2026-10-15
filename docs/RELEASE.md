# Compilar y publicar

1. Leer PROGRESS.md y CONFIGURATION.md. Conservar la firma privada existente.
2. `flutter pub get --enforce-lockfile`.
3. `dart format --output=none --set-exit-if-changed lib test integration_test`.
4. `flutter analyze --fatal-infos --no-pub`, `flutter test --no-pub` y `cd server && npm test`.
5. `flutter test integration_test/app_test.dart -d emulator-5554 --no-pub` con un emulador de desarrollo. No ejecutarlo simultáneamente con otra compilación Flutter: ambos modifican el registro de plugins.
6. `flutter build apk --release --no-pub`. Para servicios reales, añadir `--dart-define-from-file=config/app.json`.
7. Verificar firma con `apksigner verify --verbose --print-certs`; inspeccionar SDK y paquete con `apkanalyzer` o `aapt`.
8. Instalar el APK real, revisar Inicio/editor y confirmar persistencia tras cerrar el proceso. Una app firmada en debug no puede actualizarse con una firma de release: usar un emulador de desarrollo separado.
9. Publicar una GitHub Release etiquetada `v<versión>` con APK, SHA-256 y notas que distingan servicios pendientes de configuración.

GitHub Actions verifica código y pruebas en cada push. El flujo manual de APK requiere los secretos ANDROID_KEYSTORE_B64, ANDROID_STORE_PASSWORD, ANDROID_KEY_PASSWORD y ANDROID_KEY_ALIAS. No los configura ni expone esta entrega; el primer APK se firma localmente.

No afirmar compatibilidad probada con versiones de Android/iOS que no se hayan ejecutado. API 26 es el mínimo declarado, no una evidencia de prueba en Android 8. iOS necesita macOS, configuración de Google y validación de plugins/firmas antes de distribuir IPA.
