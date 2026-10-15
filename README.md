# DraftAI
Aplicación Flutter de apuntes para Desarrollo de Software II. Android primero, datos locales y diseño basado en el mockup entregado.

[Descargar APK firmado 0.1.0](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.1.0) · [Configuración de servicios](docs/CONFIGURATION.md) · [Continuidad](docs/PROGRESS.md)

Notas con formato, imágenes y cámara, carpetas/categorías, búsqueda y voz, historial, papelera y exportación PDF/Word/TXT/Markdown. Datos cifrados localmente. Gratis adjunta imágenes sin OCR; Pro y el OCR sin proveedor son demostrativos. Google e IA remota requieren configuración.

![Inicio del APK Android](docs/screenshots/android-release-home.png)

## Entorno fijado
- Flutter **3.47.2**, Dart **3.13.2**, Java **17**.
- Android mínimo **8.0 / API 26**, compile/target **36**.
- iOS mínimo **15.0**; configuración preparada, requiere validación en macOS.
- Dependencias exactas en `pubspec.yaml`, resolución en `pubspec.lock`, SDK en `.fvmrc`.

## Ejecución
`flutter pub get`, `dart run build_runner build`, `flutter run`.

## Desarrollo y continuidad
Consultar `docs/PROGRESS.md`, `docs/ARCHITECTURE.md` y `docs/TESTING.md` antes de continuar. El material `Contexto/` es referencia local y no se modifica ni se publica.

## Servicios
Sin credenciales debe funcionar el modo invitado. La IA remota y Google requieren configuración: ver `docs/CONFIGURATION.md`. Los planes son demostrativos y no cobran dinero.
