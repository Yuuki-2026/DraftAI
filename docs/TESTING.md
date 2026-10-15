# Estrategia de verificación
1. Unitarias: entidades, validación, permisos del plan, historial, límites diarios, selección por fechas y prompts.
2. Integración: DAO + SQLite real en memoria y archivo; relaciones, transacciones, migraciones, persistencia tras reinicio y traducción de errores. Servicios remotos con cliente simulado.
3. Sistema: integración Flutter en emulador Android: invitado, crear/editar/reabrir, adjuntar, buscar, papelera/restaurar, exportar y Pro demostrativo. Widget tests en 320, 390, 600 y 1000 px y texto ampliado. Capturas y revisión visual contra mockup.

Comandos: flutter analyze --fatal-infos; flutter test; flutter test integration_test -d <emulador>; flutter build apk --release.
Una compilación no demuestra por sí sola que se probó en un dispositivo. Registrar resultados y limitaciones reales en PROGRESS.md.
