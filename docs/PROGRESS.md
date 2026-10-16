# Continuidad · 0.2.3 Beta 2

Solicitud: corregir documento en blanco al guardar y volver a editar; fecha discreta, LaTeX, interlineado y aviso de exportación. Sin funciones adicionales. Se separó el lector del editor: la vista de edición se monta de nuevo al entrar, con clave por controlador/modo, foco solicitado después del montaje y recarga de la copia canónica persistida tras guardar. Se mantienen borradores manuales y confirmación al salir.

Fechas de temas convertidas de H3 a texto de 11 puntos; compatibilidad con fechas de Beta 1. Lectura preserva formato y medios intercalados. LaTeX local con flutter_math_fork 0.7.4 exacto; soporta delimitadores dólar, doble dólar, paréntesis y corchetes escapados. Fuente TeX original conservada, expresiones no válidas/extendidas muestran texto. No WebView ni servicio externo para renderizar. Edición mantiene código; lectura lo presenta visualmente.

Exportación: PDF/Word incluyen imágenes, no el contenido de PDF u otros adjuntos. TXT/MD no incluyen imágenes ni adjuntos. El diálogo identifica archivos excluidos y aclara que las fórmulas se exportan como fuente LaTeX; los originales siguen en DraftAI. Se simplifican algunos estilos de exportación.

Observaciones añadidas durante la implementación: selector manual reconstruido con el HTML hazlo-tu-categorizar (vista previa, pasos, buscador de carpetas y apuntes, micrófono, selección y confirmación). El mismo selector edita destinos de IA. Las fotos y PDF se previsualizan antes de guardar reutilizando el visor nativo existente; zoom por pellizco/doble toque. Acciones rápidas de Inicio y listado: papelera, exportar y resumen de los apuntes completos seleccionados; menús de tarjetas y del apunte usan panel común con el diseño del mockup. Exportación con tarjetas y etiquetas de extensión. Encabezado incluye lupa/micrófono agrupados y avatar; lectura/exportar/Más también arriba del documento. Buscador con Todo/Título/Tema compartido desde menú y lupa. Papelera en cuadrícula, selección/restauración/borrado; el aviso informa la retención real (no hay purga automática de 30 días). Google de prueba usa la foto de ejemplo ya presente en Contexto, copiada a assets sin modificar la referencia.

No se ejecutan pruebas, emulador ni capturas por instrucción expresa del propietario. Se registra solo revisión de código, compilación y verificación del artefacto firmado. Servidor/túnel permanecen apagados. **Publicado:** [v0.2.3-beta.2](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.2.3-beta.2) · 0.2.3-beta.2+7, Android min API 26/target 36. APK de 84492351 bytes, firmado con el certificado existente; ausencia de claves de proveedor comprobada en el APK y en Git. SHA-256: `7698ee9b36d1d14214a72bc65d975d90fe127a3558f4ba2a96e2d9762e0599d5`. Tamaño y digest también verificados en los adjuntos de GitHub. Código compilado: `d97c850382215746d965ddad1e6ad9b5092b5745`. Acciones de selección fijas sobre el contenido para permanecer visibles al desplazarse. No se ejecutaron pruebas funcionales ni validación visual de esta beta por indicación del propietario.

---

# Continuidad · 0.2.3 Beta 1

Cambios solicitados en la captura del propietario: guardado explícito, aviso Guardar/Descartar/Seguir editando, editor estable al pegar y escribir, volver desde lectura regresa al apunte, contador eliminado. Añadir tema crea un encabezado dentro del mismo documento. Fechas encima de cada tema: última edición del tema, una sola fecha por tema, sin duplicados al guardar varias veces el mismo día. Los temas que no cambian conservan su fecha. La fecha no pretende ser una copia histórica del contenido; las versiones anteriores siguen en Historial.

Google en beta: botón visible con aviso explícito de no disponibilidad y elección de entrar como usuario de prueba local. No se invoca Google/Firebase ni se vincula una cuenta; preferencia local beta_user distingue el perfil. Cancelar no entra. IA: debe comprobar conexión autenticada antes de mostrar modelo conectado. Sin código/token válido no muestra conexión. La selección por fechas intersecta los apuntes y temas marcados; nunca incluye automáticamente todos los apuntes del rango. No se envían los cuerpos de temas excluidos. No se cambiaron proveedores, modelos ni límites.

Validación acotada: 24 comprobaciones de fechas, edición, selección, persistencia y documentos aprobadas en unos tres segundos de ejecución. Comprobación adicional del botón Añadir tema y del acceso Google beta aprobada; análisis estático sin hallazgos. Total: 26 casos distintos aprobados entre los lotes acotados. Se corrigió además la disposición del campo del diálogo de tema durante su cierre, detectada por la prueba del botón. Sin emulador, capturas ni llamadas de pago. Servidor y túnel permanecen apagados por solicitud del propietario.

Versión 0.2.3-beta.1+6, Android mínimo API 26/target 36. README y release breves para el público; entrega marcada Beta de pruebas. **Publicado:** [v0.2.3-beta.1](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.2.3-beta.1) como prerelease Beta testing. APK de 80613010 bytes con el certificado existente, versión y SDK verificados; claves de proveedor ausentes del APK y auditadas en Git. SHA-256: `e5ca2dc916d4594d1f573a6799b08d95bd863bcea3542727db1cb3d5e8c02048`. Tamaño y digest comprobados en GitHub. Commit compilado: `0eaa39dd018ae62acc7578d9ae538b8cb1dbf758`.

---

# Continuidad 0.2.2

Implementado: análisis real por fuente (imagen/PDF/TXT/MD), revisión manual o IA con carpeta y apunte, resumen al final y modelo, clasificación académica, grupos de cinco; corrección de Pro perdido al emparejar, reconexión y cuotas persistentes. Lectura sin barra inferior, formato de edición y carpetas/listas plegables. Revisados todos los 153 HTML: docs/MOCKUP_REVIEW_0.2.2.md.

Comprobaciones breves: siete del servidor; operación real sintética de ocho segundos con OpenAI; análisis estático. No se ejecutó suite Flutter completa ni emulador. La revisión visual final en teléfono sigue pendiente del propietario.

Versión **0.2.2+5 publicada**: [v0.2.2](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.2.2). APK firmado de 80465550 bytes, certificado existente conservado, min SDK 26 / target 36; auditoría de las tres claves de proveedor aprobada en APK y 292 blobs de Git. SHA-256: `241ea4c9f9038efa3ae9766d0a95ebda1ef2a1b77e17cde31a28d33ad88de9e3`. Tamaño y digest verificados también en los adjuntos de GitHub. Código compilado: `8a25b9b1c1209a6216734b10835834efdd95b2f2`. Nunca publicar Contexto, credenciales ni códigos de conexión. Servidor privado de prueba con códigos separados Gratis/Pro. Ver docs/TEST_SERVER.md.

---

# Continuidad de DraftAI

## Objetivo y estado
**Entregado:** [DraftAI 0.2.2 de pruebas](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.2.2), con APK firmado y SHA256SUMS.txt publicados en GitHub Releases. SDK fijado: Flutter 3.47.2, Dart 3.13.2, Java 17. Android min API 26, compile/target 36. iOS 15 preparado, aún sin validación en macOS.

## Acuerdos
Notas exclusivamente locales. Diseño canónico en Contexto/Mockup/mockup_screens y mockup.css, sin modificar las referencias. Gratis permite texto con cuotas y adjuntar imágenes; lectura remota de imágenes solo para dispositivos de prueba Pro autorizados. Google y pagos son pendientes; planes demostrativos. Gratis usa Groq openai/gpt-oss-20b. Pro autorizado usa OpenAI gpt-5-nano-2025-08-07 para texto/imágenes; guardas de seguridad en Groq. No hay modelo instalado localmente. Se mantienen como futuras decisiones los identificadores de Luna y Jev. Claves privadas únicamente en el servidor, cifradas con Windows fuera de Git.

## Etapas iniciales (0.1.0)
- [x] Entorno y plataformas fijados, documentación arquitectónica.
- [x] Dominio, contratos, casos de uso, Drift/DAO, cifrado AES-GCM, Keystore/Keychain y migración.
- [x] Interfaz adaptable basada en mockup, crear/editar, carpetas/categorías, búsqueda y papelera.
- [x] Cámara, adjuntos cifrados, voz, exportación PDF/DOCX/TXT/MD, historial y preferencias.
- [x] Pro demostrativo, servicio de IA sustituible, gateway HTTPS preparado y Google configurable.
- [x] 27 pruebas locales aprobadas y analizador sin hallazgos; 3 pruebas del gateway aprobadas.
- [x] Prueba de sistema en Android 14/API 34: crear, editar, reabrir, papelera/restaurar y Pro. Analizador y 27 pruebas locales aprobados tras los últimos ajustes.
- [x] APK de release firmado (esquema v2/RSA 3072), metadatos verificados e instalado en Android 14. Nota creada con teclado real y conservada después de actualizar y reiniciar el proceso.
- [x] GitHub Release v0.1.0 publicada; tamaño y SHA-256 de los archivos subidos verificados.

## Verificación inicial (0.1.0)
Las pruebas cubren CRUD, cifrado y manipulación detectada, relaciones, migración v1→v2, reinicio de SQLite, historial, cuotas, prompts, respuestas del servicio y exportación de imágenes con proporción conservada. La interfaz se prueba a 320/390/600/1000 px y escala de texto 1.0/1.5, incluyendo editor. PDF de muestra renderizado y revisado. Hay capturas locales en artifacts/, fuera de Git.

## Actualización 0.1.1 publicada
Descripción general de DraftAI como aplicación para crear y organizar notas con texto e imágenes locales. Textos actualizados en README, arquitectura, términos de uso, Acerca de y notas de publicación. Nombre, diseño y funciones conservados. La descripción publicada de v0.1.0 también se actualizó.

Validación de esta actualización: analizador sin hallazgos y 27 pruebas Flutter aprobadas. APK firmado con el certificado existente, versión 0.1.1+2, mínimo API 26 y target 36 verificados. Instalado como actualización en Android 14/API 34: la nota PruebaRelease se conservó y se comprobaron los textos nuevos en Acerca de y Términos de uso. No se repitió la integración funcional ni el gateway porque solo cambiaron textos y versión. GitHub Release v0.1.1 publicada; tamaño y SHA-256 verificados en los adjuntos subidos.

La primera compilación agotó memoria del equipo; se completó con un límite local de 3 GiB para Gradle y dos workers mediante GRADLE_OPTS, sin cambiar las opciones versionadas del proyecto. Registros en artifacts/text-update-*.log.

## Continuar desde aquí
1. La entrega Android 0.2.1 de pruebas está publicada. El servidor temporal Groq funciona sin Google mientras la computadora y el túnel estén activos. Acceso privado en el perfil del propietario, fuera de Git; ver docs/TEST_SERVER.md. Próximo: pruebas funcionales y visuales del propietario en su teléfono y correcciones según sus resultados.
2. Antes de modificar, leer AGENTS.md y las decisiones de arquitectura. Mantener diseño del mockup y datos exclusivamente locales.
3. Conservar android/draftai-release.jks y android/key.properties: son privados y se necesitan para futuras actualizaciones.
4. Incrementar versión/build en pubspec.yaml para la siguiente release. Ver docs/RELEASE.md; compilar release sin --no-pub para regenerar correctamente plugins nativos.
5. Volver a comprobar integración Android tras cambios funcionales. Para iOS se requiere macOS y validación propia antes de distribuir.

## Pendiente del propietario
Probar el APK en el teléfono y conectar con la guía privada local. Autorizar ese dispositivo desde la computadora para visión Pro de pruebas. Firebase/Google y pagos reales quedan para otra fase según docs/CONFIGURATION.md; no se necesitan para el modo invitado ni para el servidor temporal actual. Producción requiere alojamiento estable, cuotas compartidas y derechos de pago verificados. No hay sincronización ni pagos reales.

## Artefacto verificado actual
`artifacts/DraftAI-0.2.1-android.apk` (79416786 bytes). SHA-256: `7abed525326c60768ee697b9f47452360c4d0ae0d9332d8647bd8b9a0fc3dbae`. Misma firma de actualizaciones anteriores. GitHub confirmó tamaños y digest del APK y SHA256SUMS.txt publicados en v0.2.1. No se hicieron instalación/emulador, capturas ni pruebas automatizadas de 0.2.1 por petición del propietario; no reutilizar la evidencia Android de 0.2.0 como prueba de esta interfaz.

## Integración 0.2.0 verificada para publicación
Rama integration/v0.2.0: feat/ui-organizacion c0dd60a integrada por merge df0cca9; nuestro bloque feat/editor-medios-ia integrado por 5a8029f. PR #1 y #2 conservan los commits. Estado de idioma unificado con AppController del colaborador; helper tr(context, texto) y catálogo local en strings.dart.

Implementado: medios dentro de Delta con identificadores de adjunto; versión 2 del payload, lectura compatible v1 y separación de migración/medios retirados. Galería y PDF nativo Android, importación de lote a nota elegida, exportación ordenada, imágenes verificadas por firma/decodificador y PDF por firma/parser Android. Biblioteca opcional de 20 ejemplos y limpieza selectiva. Datos anteriores y clave/firma conservados.

Servidor temporal de pruebas con claves DPAPI fuera de Git, emparejamiento sin Google, modelos exactos y presupuesto persistente. Texto real, bloqueo de petición dañina y cuota comprobados; lectura real de imagen sintética comprobada. 23 pruebas principales y 6 de servidor aprobadas. Analizador sin hallazgos antes de la compilación final. El propietario pidió revisar la entrega visual por código, sin pruebas/capturas de ese bloque; no se afirma validación visual completa.

APK 0.2.0+3 compilado, firma v2 y certificado anterior verificados; mínimo API 26, target 36. Auditoría de todas las entradas del APK contra las claves proporcionadas: sin coincidencias. Tamaño 79121650 bytes; SHA-256 `a9248a93401dfb4972f09d9fba57e9c489669e7cf87b6bd658efa69692bd5502`. Código del APK: 9290b96.

Instalado como actualización en Android 14/API 34, versión 0.2.0+3 confirmada por Android; actividad iniciada y proceso vivo sin excepción de arranque en el registro revisado. No se ejecutó una nueva prueba funcional completa ni se tomaron capturas. HTTPS del servidor temporal verificado. PR #3 fusionado en main (4fe4665); PR #1 y #2 figuran fusionados. Release v0.2.0 publicada como versión de pruebas con APK y SHA256SUMS.txt verificados. Auditoría adicional de 233 blobs de todas las referencias Git: sin coincidencias con las claves facilitadas. Servidor de prueba requiere computadora/túnel activos; no confundir con servicio productivo. Google/pagos/OpenAI de Pro siguen pendientes.


## Corrección 0.2.1 publicada
Petición del propietario: corregir fidelidad al HTML/CSS y capturas del mockup y publicar rápidamente sin pruebas/capturas nuevas. Se corrigen carpetas, acciones visibles, modo lectura, dos barras del editor, inserción discreta y zoom real por doble toque. No se crean nuevas categorías; se conserva compatibilidad con las anteriores. Referencia PDF de requerimientos revisada como material de consulta; las indicaciones actuales del propietario prevalecen.

Biblioteca opcional ampliada a 120 apuntes, 8 carpetas, 24 temas, fechas de ocho meses y adjuntos generados. Clave OpenAI actualizada y cifrada con DPAPI fuera del repositorio. Modelo económico comprobado en /v1/models: gpt-5-nano-2025-08-07. Precio de referencia oficial: input USD 0.05 / output USD 0.40 por millón de tokens. Figura como modelo antiguo en documentación, pero la cuenta conserva acceso. No hay sustitución automática por otro más caro. Pro usa OpenAI; guardas usan Groq; presupuesto global común.

Conexión Pro real verificada con material ficticio y cuotas comunes activas: resumen no vacío devuelto por gpt-5-nano-2025-08-07. Analizador sin hallazgos. APK 0.2.1+4 compilado y firma v2/certificado anterior confirmados, mínimo API 26 y target 36. Auditoría de cada entrada del APK contra las tres claves aportadas: sin coincidencias. Tamaño 79416786 bytes; SHA-256 `7abed525326c60768ee697b9f47452360c4d0ae0d9332d8647bd8b9a0fc3dbae`. Fuente del APK f38957a. No se ejecutaron suite de pruebas, capturas, instalación ni emulador por solicitud del propietario. El último dispositivo de pruebas conectado se autorizó Pro; nuevos emparejamientos siguen en Gratis hasta autorización local. Servidor reiniciado con Pro activo y mismo túnel; guía privada actualizada fuera de Git.

Release v0.2.1 publicada desde ee98524 con APK y checksum; ambos digest remotos verificados. Los commits 49ebeb5 y f38957a conservan los cambios visuales y Pro por etapas. Auditoría adicional de las tres claves contra 258 blobs de todas las referencias Git: sin coincidencias. Servidor/túnel activos y health HTTPS indica Pro disponible. Guía privada vigente CONEXION_PRUEBAS_0.2.1.txt en el perfil del propietario, fuera de Git.

Próximo: el propietario prueba esta entrega en el teléfono y comunica diferencias concretas respecto al mockup. Para cargar la biblioteca ampliada, eliminar primero los ejemplos antiguos desde Perfil; no se borran notas reales. Nuevos dispositivos requieren autorización Pro local y activación del plan demostrativo en el APK. No hay compras reales.
