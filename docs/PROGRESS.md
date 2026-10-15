# Continuidad de DraftAI

## Objetivo y estado
**Entregado:** [DraftAI 0.1.0](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.1.0), con APK firmado y SHA256SUMS.txt publicados en GitHub Releases. SDK fijado: Flutter 3.47.2, Dart 3.13.2, Java 17. Android min API 26, compile/target 36. iOS 15 preparado, aún sin validación en macOS.

## Acuerdos
Notas exclusivamente locales. Diseño canónico en Contexto/Mockup/mockup_screens y mockup.css, sin modificar las referencias. Gratis adjunta imágenes sin OCR. Pro demostrativo habilita el flujo OCR futuro; las demostraciones dicen expresamente que no leyeron las imágenes. Luna y Jev siguen sin identificadores/API oficiales confirmados. Claves privadas únicamente en el gateway.

## Etapas
- [x] Entorno y plataformas fijados, documentación arquitectónica.
- [x] Dominio, contratos, casos de uso, Drift/DAO, cifrado AES-GCM, Keystore/Keychain y migración.
- [x] Interfaz adaptable basada en mockup, crear/editar, carpetas/categorías, búsqueda y papelera.
- [x] Cámara, adjuntos cifrados, voz, exportación PDF/DOCX/TXT/MD, historial y preferencias.
- [x] Pro demostrativo, servicio de IA sustituible, gateway HTTPS preparado y Google configurable.
- [x] 27 pruebas locales aprobadas y analizador sin hallazgos; 3 pruebas del gateway aprobadas.
- [x] Prueba de sistema en Android 14/API 34: crear, editar, reabrir, papelera/restaurar y Pro. Analizador y 27 pruebas locales aprobados tras los últimos ajustes.
- [x] APK de release firmado (esquema v2/RSA 3072), metadatos verificados e instalado en Android 14. Nota creada con teclado real y conservada después de actualizar y reiniciar el proceso.
- [x] GitHub Release v0.1.0 publicada; tamaño y SHA-256 de los archivos subidos verificados.

## Verificación realizada
Las pruebas cubren CRUD, cifrado y manipulación detectada, relaciones, migración v1→v2, reinicio de SQLite, historial, cuotas, prompts, respuestas del servicio y exportación de imágenes con proporción conservada. La interfaz se prueba a 320/390/600/1000 px y escala de texto 1.0/1.5, incluyendo editor. PDF de muestra renderizado y revisado. Hay capturas locales en artifacts/, fuera de Git.

## Continuar desde aquí
1. La entrega Android 0.1.0 ya está publicada. La siguiente fase es configurar servicios reales cuando el propietario aporte su proyecto Firebase y proveedor/modelo de IA.
2. Antes de modificar, leer AGENTS.md y las decisiones de arquitectura. Mantener diseño del mockup y datos exclusivamente locales.
3. Conservar android/draftai-release.jks y android/key.properties: son privados y se necesitan para futuras actualizaciones.
4. Incrementar versión/build en pubspec.yaml para la siguiente release. Ver docs/RELEASE.md; compilar release sin --no-pub para regenerar correctamente plugins nativos.
5. Volver a comprobar integración Android tras cambios funcionales. Para iOS se requiere macOS y validación propia antes de distribuir.

## Pendiente del propietario
Configurar Firebase/Google y el proveedor real de IA según docs/CONFIGURATION.md. No se necesitan para el modo invitado local. El gateway es de referencia; producción requiere alojamiento, cuotas compartidas y derechos de pago verificados. No hay sincronización ni pagos reales.

## Artefacto verificado
`artifacts/DraftAI-0.1.0-android.apk` (77630478 bytes). SHA-256: `5bcc2e0fe28f27f0e7018c26c8e4948dd1c300c98e72a3c0db7fafffa409ff4a`. Sin plugin integration_test dentro de los DEX de release. Última corrección adicional: Word convierte WebP a PNG y conserva proporción; prueba de exportación aprobada.
