# Continuidad de DraftAI

## Objetivo y estado
**Entregado:** [DraftAI 0.1.1](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.1.1), con APK firmado y SHA256SUMS.txt publicados en GitHub Releases. SDK fijado: Flutter 3.47.2, Dart 3.13.2, Java 17. Android min API 26, compile/target 36. iOS 15 preparado, aún sin validación en macOS.

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

## Actualización 0.1.1 publicada
Descripción general de DraftAI como aplicación para crear y organizar notas con texto e imágenes locales. Textos actualizados en README, arquitectura, términos de uso, Acerca de y notas de publicación. Nombre, diseño y funciones conservados. La descripción publicada de v0.1.0 también se actualizó.

Validación de esta actualización: analizador sin hallazgos y 27 pruebas Flutter aprobadas. APK firmado con el certificado existente, versión 0.1.1+2, mínimo API 26 y target 36 verificados. Instalado como actualización en Android 14/API 34: la nota PruebaRelease se conservó y se comprobaron los textos nuevos en Acerca de y Términos de uso. No se repitió la integración funcional ni el gateway porque solo cambiaron textos y versión. GitHub Release v0.1.1 publicada; tamaño y SHA-256 verificados en los adjuntos subidos.

La primera compilación agotó memoria del equipo; se completó con un límite local de 3 GiB para Gradle y dos workers mediante GRADLE_OPTS, sin cambiar las opciones versionadas del proyecto. Registros en artifacts/text-update-*.log.

## Continuar desde aquí
1. La entrega Android 0.1.1 ya está publicada. La siguiente fase es configurar servicios reales cuando el propietario aporte su proyecto Firebase y proveedor/modelo de IA.
2. Antes de modificar, leer AGENTS.md y las decisiones de arquitectura. Mantener diseño del mockup y datos exclusivamente locales.
3. Conservar android/draftai-release.jks y android/key.properties: son privados y se necesitan para futuras actualizaciones.
4. Incrementar versión/build en pubspec.yaml para la siguiente release. Ver docs/RELEASE.md; compilar release sin --no-pub para regenerar correctamente plugins nativos.
5. Volver a comprobar integración Android tras cambios funcionales. Para iOS se requiere macOS y validación propia antes de distribuir.

## Pendiente del propietario
Configurar Firebase/Google y el proveedor real de IA según docs/CONFIGURATION.md. No se necesitan para el modo invitado local. El gateway es de referencia; producción requiere alojamiento, cuotas compartidas y derechos de pago verificados. No hay sincronización ni pagos reales.

## Artefacto verificado
`artifacts/DraftAI-0.1.1-android.apk` (77630478 bytes). SHA-256: `b87a00e8e15cc986955a6ef1b0536e547a224785bcfab4e13528cb289e7b9394`. Firma conservada respecto a v0.1.0.

## Integración 0.2.0 verificada para publicación
Rama integration/v0.2.0: feat/ui-organizacion c0dd60a integrada por merge df0cca9; nuestro bloque feat/editor-medios-ia integrado por 5a8029f. PR #1 y #2 conservan los commits. Estado de idioma unificado con AppController del colaborador; helper tr(context, texto) y catálogo local en strings.dart.

Implementado: medios dentro de Delta con identificadores de adjunto; versión 2 del payload, lectura compatible v1 y separación de migración/medios retirados. Galería y PDF nativo Android, importación de lote a nota elegida, exportación ordenada, imágenes verificadas por firma/decodificador y PDF por firma/parser Android. Biblioteca opcional de 20 ejemplos y limpieza selectiva. Datos anteriores y clave/firma conservados.

Servidor temporal de pruebas con claves DPAPI fuera de Git, emparejamiento sin Google, modelos exactos y presupuesto persistente. Texto real, bloqueo de petición dañina y cuota comprobados; lectura real de imagen sintética comprobada. 23 pruebas principales y 6 de servidor aprobadas. Analizador sin hallazgos antes de la compilación final. El propietario pidió revisar la entrega visual por código, sin pruebas/capturas de ese bloque; no se afirma validación visual completa.

APK 0.2.0+3 compilado, firma v2 y certificado anterior verificados; mínimo API 26, target 36. Auditoría de todas las entradas del APK contra las claves proporcionadas: sin coincidencias. Tamaño 79121650 bytes; SHA-256 `a9248a93401dfb4972f09d9fba57e9c489669e7cf87b6bd658efa69692bd5502`. Código del APK: 9290b96.

Instalado como actualización en Android 14/API 34, versión 0.2.0+3 confirmada por Android; actividad iniciada y proceso vivo sin excepción de arranque en el registro revisado. No se ejecutó una nueva prueba funcional completa ni se tomaron capturas. HTTPS del servidor temporal verificado. Pendiente: integrar a main y publicar release. Servidor de prueba requiere computadora/túnel activos; no confundir con servicio productivo. Google/pagos/OpenAI de Pro siguen pendientes.
