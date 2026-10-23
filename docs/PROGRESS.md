# Corrección UI · recorte de perfil y botón de tablas · 2026-10-22

El selector de foto limita el área de recorte al espacio real disponible y captura un viewport cuadrado con máscara circular; los avatares fuerzan un contenedor cuadrado antes del recorte para evitar óvalos por restricciones de pantalla. El botón Insertar tabla ahora usa un icono de cuadrícula más grande y un fondo tonal para distinguirlo en la barra de edición. El análisis estático también encontró y se corrigieron dos errores de compilación preexistentes: un método `didUpdateWidget` duplicado y el acceso a `plainText` mediante una interfaz explícita.

Análisis dirigido de los cinco archivos afectados: sin errores; quedaron solo avisos informativos existentes. No se compiló APK ni se ejecutó en dispositivo. Pendiente: revisar ambos cambios en el teléfono cuando se prepare el siguiente APK.

# Continuidad · Acceso Google real y aislamiento local · 2026-10-22

Se sustituyó el acceso de “usuario de prueba” por Firebase Authentication/Google Sign-In. Android procesa `google-services.json` mediante Google Services Gradle Plugin; la app ya no depende de `--dart-define` para los valores públicos de Firebase. La biblioteca Invitado conserva la base y clave existentes. Cada UID abre una base y clave AES-GCM independientes, con sus propios adjuntos y preferencias.

Al iniciar sesión desde Invitado con apuntes, aparece una decisión para moverlos a la cuenta o dejarlos en Invitado. El traslado vuelve a cifrar notas y archivos con la clave del UID, conserva carpetas, categorías, papelera e historial, verifica que destino y adjuntos abran antes de limpiar la fuente y usa identificadores de adjuntos estables para reintentar tras interrupciones. Al rechazar, las bibliotecas se mantienen separadas. Si se interrumpe la copia, el original se conserva. No se habilitó Firestore/Cloud Storage: el contenido sigue solo en este teléfono, sin recuperación en otro dispositivo ni sincronización.

No se abrió la app, no se instaló APK y no se ejecutaron pruebas ni emulador: el propietario indicó que realizará la prueba cuando el acceso y la transferencia estén implementados. Pendiente de validación en teléfono: selección Google, cambio entre UID A/UID B/Invitado, aceptar/rechazar traslado e interrupción durante una biblioteca con adjuntos/historial.

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

## Corrección del servidor: contenido académico y acceso de prueba
Se exige explicación académica en español en lugar de descripción visual, traducción del contenido y ausencia de anotaciones de imagen. Rechazos no académicos/ilegibles vacían destinos en servidor; catálogo completo sin forzar única carpeta. Diez cupos, cuotas y presupuesto global intactos. Gratis mantiene Groq para selección/resumen; Pro OpenAI para fuentes. Sin cambios Flutter ni APK. Validación: sintaxis Node y comprobaciones locales del contrato; sin llamadas de pago ni pruebas Android.

Aclaración posterior: texto, resumen y mejora conservan el idioma predominante de la fuente; no se traduce automáticamente. Los avisos de revisión siguen en español. Se comprobó sintaxis, sin llamadas de pago.

## Resumen mejorado para estudiar
Texto de fuente presentado como apuntes claros y resumen didáctico con definiciones, diferencias y ejemplos pertinentes, sin descripciones visuales, nombres de archivo ni comentarios de idioma. Limitaciones solo en aviso de revisión español. GET/PUT y otros identificadores no determinan idioma inglés. Rechazo explícito de prefijos de descripción visual conocidos, sin reintentos automáticos. Idioma predominante conservado. Sintaxis Node comprobada; sin consumo de API ni pruebas Android.

## Ampliación temporal de pruebas autorizada por el propietario
16/10/2026 Lima: 120 llamadas globales, 20 dispositivos, Gratis 10 y Pro 30 operaciones. Retorno automático a valores anteriores a las 00:00 del 17/10 Lima, evaluado por solicitud sin depender de un reinicio. Consumo acumulado preservado; presupuesto persistente sincroniza contador secundario. Raíz HTTPS informativa y códigos persistentes de 24h. Sin cambios APK. Verificación de sintaxis y salud; sin llamadas de pago.

## Beta 0.2.3-beta.3+8: cuota real
Se elimina el bloqueo local duplicado cuando el servicio expone acceso remoto. El servidor es autoridad de usos; contador en Perfil e IA con actualización manual y tras operaciones, incluido fallo. Estado autenticado incluye usados/límite/presupuesto global persistente. Conexión expone errores seguros del servidor. Sin migraciones de notas. Verificación de compilación, análisis y firma; sin emulador ni capturas para agilizar según petición del usuario.

Comprobaciones beta.3: Node --check correcto; presupuesto persistente 1 prueba aprobada sin llamadas externas. Flutter analyze terminó con 25 avisos de estilo/contexto (no se declara limpio). No se ejecutaron pruebas Flutter, emulador ni capturas para priorizar la entrega solicitada.

Beta.3 publicada: https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.2.3-beta.3 . APK firmado 84492431 bytes; SHA-256 36f76ea4d570909fe40cb67afc5b8e3cd07602fd331bf431477a1a5b5f5860f3. Digest y tamaño remoto verificados. Fuente edbcc280b8387f62755ebf5bba992b47961e5195. Se conserva firma, notas y endpoint; actualizar sin desinstalar.

## Ajustes de experiencia de uso sobre beta.3
Se actualizó `main` desde `origin/main` hasta `6a385c8` antes de modificar la app. Guardar apunte ahora usa botón destacado; entrar en edición no enfoca el editor ni abre el teclado; dictado oculta el teclado; los títulos vacíos no se guardan y al crear nota se muestra “Un buen nombre ayuda a clasificar mejor a la IA”. Se habilitó el color de fondo del texto para usarlo como resaltador y se evita que el selector de color de carpeta herede el foco del teclado.

La pantalla de importación ahora muestra un estado inicial y acciones de elegir imágenes/archivos antes de que haya una primera fuente; al añadirlas presenta su cantidad y los destinos. Borradores revisados por IA y destinos manuales se conservan al volver a la pantalla de lote para no repetir el análisis ni perder la revisión; se limpian al guardar o quitar una fuente.

Verificación: `dart format` aplicado; `dart analyze` sobre los cinco archivos cambiados terminó sin errores y mostró 10 avisos informativos de estilo/contexto en `library_page.dart` y `note_page.dart`. `flutter analyze --fatal-infos` quedó detenido durante el análisis global prolongado, así que no se declara como completado. No se ejecutaron pruebas automatizadas ni emulador. No se creó GCP ni se almacenaron credenciales; nube, propiedad/recuperación segura de notas y personalización de nombre/icono quedan para la etapa posterior que pidió el propietario.

## Beta 0.2.3-beta.4 · mejoras locales de UI/UX
Se ajustó Guardar para conservar su etiqueta y estilo de texto: fondo blanco y texto negro en tema oscuro; fondo negro y texto blanco en tema claro. El selector de cuadrícula/lista de apuntes conserva su preferencia y las tarjetas de cuadrícula muestran texto o una imagen real del apunte. Se añadieron plantillas por apunte (liso, renglones, cuadrícula, puntos e interlineado amplio), guardadas localmente.

Los selectores de color de texto/resaltador usan paletas táctiles sin campo HEX ni teclado. El selector de carpeta conserva el control visual de color y ahora muestra HEX sin abrir el teclado. Se añadió inserción y edición de tablas 3×3 dentro del documento; la lectura las dibuja como tabla y las exportaciones las representan como filas de texto. Preferencias permite personalizar el nombre que aparece dentro de DraftAI y en el título de la ventana; el icono y la etiqueta del lanzador siguen siendo DraftAI.

El perfil invitado ya no muestra una tarjeta de suscripción ni el estado Pro por preferencia local; esas opciones solo aparecen si hay identidad Google configurada y nombre de cuenta. Se mantienen los cambios anteriores: título requerido, ayuda para nombrar, edición sin teclado automático, dictado sin teclado, lotes de captura con estado inicial coherente y conservación de borradores para no volver a analizar fuentes al regresar. La clasificación existente rechaza fuentes no académicas o ilegibles y no fuerza un destino cuando la coincidencia es dudosa.

Se completó el cuestionario de repaso local: genera preguntas de opción múltiple con frases del apunte, registra respuestas y muestra el resultado sin enviar texto a un servicio. El modo lectura permite mostrar u ocultar un indicador aproximado calculado con el desplazamiento visible; no representa páginas PDF reales. Se movió Eliminar fuera de Más, con confirmación; al leer se ocultan acciones de edición, borrado, historial y renombrado. Preferencias ahora permite elegir entre tres iconos del lanzador Android; el nombre dentro de la app sigue siendo editable.

Fuera de este bloque: base de datos GCP, credenciales, identidad Google operativa, separación criptográfica por cuenta y traslado invitado→Google. La publicación/actualización beta.4 se hará después por indicación del propietario. No se encontraron `android/key.properties` ni `android/draftai-release.jks`; no se generó una clave nueva para no romper la firma beta.3.

Verificación de este bloque: `dart format`, análisis acotado sin errores (12 avisos informativos de estilo/contexto) y `flutter build apk --debug` compilado correctamente. No se ejecutaron pruebas automatizadas ni se abrió el emulador. No se creó APK firmado, no se cambió la versión, ni se hizo commit, push o publicación. Kotlin incremental continúa desactivado y Gradle limitado a 3 GB/dos workers para evitar el error previo de caché entre unidades Windows.

## Correcciones de UI/UX indicadas por el propietario · 21/10/2026

Esta sección sustituye las afirmaciones anteriores de Beta 0.2.3-beta.4 cuando se contradicen con las correcciones más recientes. Trabajo solo local; no se hizo commit, push, release ni despliegue.

### Lista vigente de tareas y estado
- [x] Mantener el texto de Guardar y resaltarlo: fondo blanco/texto negro en tema oscuro y fondo negro/texto blanco en tema claro.
- [x] Evitar teclado al entrar a editar, dictar y usar controles de formato; ocultar teclado desde color, tamaño, tipografía y resaltador, conservando la selección del texto.
- [x] Conservar la paleta de color de texto y añadir junto a ella el resaltador con icono reconocible, sin fondo amarillo y con colores activos para la escritura hasta cambiarlos o quitarlos.
- [x] Exigir título no vacío y permitir que la ayuda de nombre ocupe dos líneas en pantallas estrechas.
- [x] Corregir el error de `TextEditingController` al cerrar creación de apuntes/carpetas. Los campos de nota, carpeta y tabla ya no se destruyen antes de cerrar su diálogo.
- [x] Reubicar los fondos de hoja Liso, Renglones, Cuadrícula, Puntos e Interlineado amplio en Perfil > Preferencias; se guardan como preferencia global y se previsualizan.
- [x] Separar los dos usos de “cuadrícula”: Preferencias controla el patrón de la hoja; la pastilla de Inicio cambia de forma independiente la distribución de carpetas entre lista y dos columnas.
- [x] Reemplazar el cuestionario local por generación remota a partir del texto del apunte, con validación de respuesta/opciones, aviso antes de enviar y estado de error/reintento. App y gateway local implementan el contrato `action: quiz`.
- [x] Cambiar personalización a nombre y foto del perfil, con “Modo invitado” como nombre por defecto para invitado y selección de foto desde la galería.
- [x] Retirar el selector de nombre de la app y de icono del lanzador; se conserva el nombre de producto DraftAI y su icono fijo.
- [x] Unificar el menú + Nuevo y el menú Más en paneles con botones distinguibles en modo claro y oscuro; quitar la instrucción confusa para cerrar tocando afuera.
- [x] Usar ese mismo panel para insertar imágenes, abrir Cámara o adjuntar archivos desde el editor.
- [x] Reducir trabajo por pulsación: el editor ya no serializa el apunte completo cada vez que cambia texto; se reutilizan lecturas cifradas de imágenes y se limitan dimensiones de decodificación en vistas previas.
- [x] Mantener tablas editables 3×3, clasificación sin destino forzado cuando la coincidencia es dudosa, lote de captura con borradores y el indicador de lectura aproximado.
- [x] Añadir selector Lista/Cuadrícula junto a “Nueva carpeta”, colocado inmediatamente a su derecha; la cuadrícula tiene dos columnas, previsualiza apuntes y usa el botón breve “Abrir”.
- [x] Cambiar el color de carpeta desde una rueda multicolor con barra de tono; quitar el texto HEX como control visible.
- [x] Conservar la paleta de texto y añadir al lado un resaltador compacto y funcional, sin fondo amarillo, con opción “Sin relleno” y sin bloque vacío en la barra de formato.
- [ ] Verificar fluidez, teclado y navegación en un teléfono Android 9/emulador. El APK de perfil se compila para esa comprobación; el rendimiento real aún depende del dispositivo.
- [ ] Conectar/desplegar el gateway actualizado para que el cuestionario IA pueda usarse. No hay URL de túnel disponible; no se envió contenido ni se llamó a proveedor en esta entrega.
- [ ] Separar notas y claves por cuenta Google y diseñar el traslado invitado→Google. Pendiente; no se cambió la bóveda actual.
- [ ] Crear base de datos/servicios en GCP y solicitar credenciales solo cuando corresponda. Diferido por indicación del propietario.
- [ ] Preparar tutorial de VM y GCP. Diferido hasta terminar UI/UX.
- [ ] Actualizar el repositorio y publicar beta.4 con APK firmado. Diferido: no se subió Git; faltan las claves originales de firma, y la etapa de publicación queda para cuando el propietario la autorice después de completar lo restante.
- [x] Preparar el plan de GCP, cuentas Google, bóvedas/cifrado por identidad, migración invitado y límites. Diseño documentado; no se aprovisionó la nube.

### Verificación de esta corrección
`dart format` aplicado (17 archivos, sin cambios pendientes); análisis de archivos modificados sin errores, con 14 avisos informativos de estilo/contexto. `node --check server/service.mjs` correcto. Se compiló `build/app/outputs/flutter-apk/app-profile.apk` (109,7 MB, modo profile) y se verificó su firma: usa el certificado Android Debug, por lo que no actualiza encima de una versión beta firmada distinta; para instalarlo hay que desinstalar primero la versión anterior y se borran sus datos locales. No se ejecutaron pruebas automatizadas ni se abrió el emulador. La fluidez en Android 9 aún requiere comprobación en dispositivo. El código del cuestionario requiere desplegar el gateway actualizado antes de funcionar con IA remota.

### Norma añadida por esta corrección
Al añadir una función, conservar las funciones existentes: el resaltador se suma al control de color de texto con controles e iconos reconocibles. Las acciones de formato no deben mostrar el teclado; al cerrar diálogos de creación, los controladores de texto deben permanecer válidos durante la animación. Los textos de ayuda deben adaptarse a pantallas estrechas. El cuestionario solicitado es remoto vía IA, nunca una generación local. La cuadrícula de Preferencias define el papel de la hoja, no tarjetas de biblioteca; la personalización es el nombre/foto del perfil, no el nombre/icono del lanzador.

## Correcciones posteriores de carpetas y paleta · 21/10/2026
- [x] Añadir junto a “Nueva carpeta” el selector visual Lista/Cuadrícula; la cuadrícula muestra dos columnas de carpetas con previsualización y acceso a sus apuntes.
- [x] Restaurar la paleta como control de color de texto dentro de la fila horizontal de formato; incluir colores Material, selector libre y “Sin color”.
- [x] Colocar el resaltador al lado, con icono de marcador sin fondo amarillo y el mismo selector con “Sin relleno”.
- [x] Cambiar el HEX visible de cada carpeta por una rueda multicolor y sumar una barra de tono arcoíris al selector de color de carpeta.

Verificación: `dart format` aplicado; análisis de los archivos afectados sin errores (12 avisos informativos); `flutter build apk --profile` compilado correctamente. No se abrió el emulador ni se ejecutaron pruebas automatizadas. Cambios locales; sin commit, push ni release.

### Norma añadida por esta corrección
El selector Lista/Cuadrícula va junto a “Nueva carpeta” y modifica únicamente la disposición visual; la cuadrícula usa dos columnas. La paleta original de color de texto se conserva dentro de la fila de formato; el resaltador se añade al lado con icono de marcador sin fondo amarillo y el mismo selector, más “Sin relleno”. El control visible de color de carpeta es una rueda multicolor, nunca un HEX.

### Ajustes de presentación posteriores · 21/10/2026
- [x] En las tarjetas de carpeta de la cuadrícula, reducir “Abrir carpeta” a “Abrir”.
- [x] Ordenar el encabezado de carpetas como “Nueva carpeta” y, a su derecha, el selector Lista/Cuadrícula.
- [x] Sustituir el botón personalizado que dejaba un bloque vacío por el botón compacto de Quill, con marcador visible sin fondo amarillo y acceso al mismo selector de resaltado.

Verificación: `dart format` aplicado; `dart analyze` de los tres archivos afectados sin errores (10 avisos informativos de estilo/contexto); `git diff --check` sin errores. APK profile compilado en `build/app/outputs/flutter-apk/app-profile.apk` (135005164 bytes); firma APK v2 verificada. SHA-256: `5D07027AE4428255EF6754E2124FB1E70885B4FE7D96DC372C543BB9F88C99BA`. No se ejecutaron pruebas ni emulador. Sin commit, push ni publicación.

### Norma añadida por esta corrección
El orden junto a “Tus carpetas” es “Nueva carpeta” primero y la pastilla de vista inmediatamente a su derecha. El botón de resaltado debe ser compacto, mostrar el icono de marcador sin fondo amarillo y usar el selector funcional; no usar `childBuilder` sin restricciones que expanda el botón en la fila de Quill.

## Ajustes finales de formato e inserción · 21/10/2026
- [x] Quitar el fondo amarillo del botón Resaltador y conservar únicamente el icono de marcador.
- [x] Mantener activo el último color de texto y de resaltado durante la edición, incluso al mover el cursor, hasta que se elija otro color o se use “Sin color”/“Sin relleno”.
- [x] Cambiar el selector de imágenes, cámara y archivos al panel común de acciones, con el estilo de “Nuevo” y “Más”.
- [x] Preparar `docs/GCP_ACCOUNT_ENCRYPTION_PLAN.md` a partir del estado del gateway y la bóveda local. No se creó ningún recurso de nube.

Verificación: `dart format` aplicado; análisis de los tres archivos afectados sin errores y con 4 avisos informativos; `git diff --check` sin errores (solo aviso de conversión CRLF/LF). APK profile compilado en `build/app/outputs/flutter-apk/app-profile.apk` (135005164 bytes), firma v2 verificada con certificado Android Debug. SHA-256: `9ECE32FDB920EE75B939D32FE13E7B4ACA11B8B23CB922E867493A6C687DB945`. No se ejecutaron pruebas ni emulador. No se creó GCP ni se modificó Git/release.

### Norma añadida por esta corrección
El resaltador no lleva fondo amarillo. Los colores elegidos se conservan como formato de escritura para el resto de la edición y solo cambian al elegir otro color o quitarlo. Insertar imágenes, abrir cámara o adjuntar archivos usa el mismo panel de acciones que “Nuevo” y “Más”. El plan de GCP debe partir de las cuotas vigentes del código, distinguir los límites temporales vencidos y explicar que una API key de proveedor vive solo en el servidor.

## Mejoras solicitadas para la siguiente entrega beta.4 · 22/10/2026

Cambios preparados en el código local de DraftAI, sin cambiar la versión `0.2.3-beta.4+9` ni publicar/actualizar el repositorio.

- [x] PDF y Word muestran una previsualización con controles para tamaño de imágenes, tamaño de títulos, márgenes, fecha, pie de página y número de página. Para una selección múltiple se puede exportar en un archivo combinado o uno por apunte.
- [x] TXT y Markdown incluyen el texto del apunte, títulos, temas, listas, tablas y resumen; sustituyen imágenes por marcadores con el nombre del archivo y no incluyen rutas internas.
- [x] Las imágenes permanecen en la posición de inserción. En edición, al seleccionar una, aparecen tiradores en las esquinas para ajustar el ancho y controles de alineación izquierda/centro/derecha. El tamaño y alineación se guardan en el documento y se aplican a lectura, vista previa y PDF/Word.
- [x] La categorización por lotes presenta una ruleta de tarjetas superpuestas: deslizar cambia la foto al frente, las demás rotan detrás y cada tarjeta muestra su número de selección original.
- [x] “Nuevo apunte” se presenta como hoja inferior rediseñada y permite escoger carpeta o crear una nueva carpeta dentro del mismo flujo, también al crear desde una carpeta existente.
- [x] Los estilos de hoja alinean renglones, cuadrícula y puntos con el desplazamiento y escala de lectura.
- [x] Las fórmulas se renderizan desde notación TeX en lectura y se convierten a una representación textual matemática legible en exportaciones, sin dejar delimitadores o comandos LaTeX crudos.
- [x] El menú de edición conserva “Insertar tabla” y ahora pregunta filas (1–12) y columnas (1–6); conserva las celdas escritas cuando se cambia el tamaño.
- [x] Perfil presenta una foto circular grande centrada y el nombre con lápiz. Al elegir una foto se abre un recorte circular con desplazamiento y zoom para ajustar el encuadre; las demás opciones del perfil se mantienen.
- [x] El traslado Invitado→Google ofrece “No volver a mostrar” y la preferencia puede volver a activarse en Preferencias. Preferencias también ofrece importar manualmente los apuntes de Invitado cuando se está usando una cuenta Google.
- [x] El traslado conserva la biblioteca original ante fallos y solo la limpia tras volver a abrir y comparar apuntes, historial y bytes de adjuntos en la bóveda cifrada de destino.
- [x] Preferencias permite elegir Inter, serif o monoespaciada para la interfaz; se añadieron etiquetas en inglés para los nuevos controles.
- [ ] Configurar una API propia en modo Invitado: se difiere expresamente para la etapa posterior indicada por el propietario.

Comprobación realizada: `dart format` en los 19 archivos Dart de esta entrega (sin cambios pendientes) y `git diff --check` sin errores. No se ejecutaron `dart analyze`, pruebas, compilación APK, emulador ni instalación en el teléfono, conforme a la instrucción de limitar esta etapa a código. La UI y los flujos aún deben comprobarse en el dispositivo cuando el propietario lo conecte. No hubo commit, push, release ni actualización de GitHub.

### Normas añadidas por las aclaraciones del propietario · 22/10/2026

- La exportación múltiple opera sobre los apuntes seleccionados y permite combinarlos o separarlos únicamente para PDF/Word.
- Una imagen insertada en el apunte debe poder redimensionarse arrastrando sus esquinas y alinearse; sus cambios permanecen guardados.
- La galería de categorización rota las fotos superpuestas y conserva a la vista el orden en que se seleccionaron.
- El flujo “Nuevo apunte” permite crear una carpeta sin salir de la carpeta/pantalla actual.
- El botón para insertar tablas está dentro del menú de edición y pide filas y columnas.
- El perfil se inspira en la composición visual de WhatsApp, sin copiarla: avatar circular grande, recorte ajustable y nombre con lápiz; se conservan las demás opciones.
- La API propia de invitado queda fuera de esta entrega.
- No instalar ni trasladar al teléfono hasta que el propietario lo conecte después de completar el trabajo de código.

## API en la nube preparada · 22/10/2026
- [x] Añadir Azure Functions Node.js v4 como destino del gateway de IA, manteniendo Firebase Authentication para identificar cuentas Google.
- [x] Verificar en el servidor el token Firebase y el proveedor Google; no enviar la clave de OpenAI ni una clave de función a la app.
- [x] Persistir la cuota diaria por UID y el límite global del proveedor en Firestore, con 30 operaciones diarias por cuenta como valor inicial configurable.
- [x] Conectar el cliente Flutter al endpoint Azure con AI_BASE_URL; cuando está configurado, utiliza automáticamente el ID token de Google y deja de pedir el código temporal de emparejamiento.
- [x] Mantener notas y adjuntos en el teléfono; la API procesa solo el contenido que el usuario elige enviar a una acción de IA.
- [ ] Crear el recurso de Azure, habilitar Firestore, guardar secretos en Key Vault, desplegar y configurar la URL real en la app.

No se generó ni instaló APK para esta etapa. El archivo build/app/outputs/flutter-apk/app-profile.apk existente se creó antes de los últimos cambios de interfaz y API, por lo que no representa el código actual. No se ejecutaron pruebas ni análisis. No se crearon recursos de nube ni se enviaron claves o credenciales.

## Separación de IA Google e Invitado · 22/10/2026
- [x] Enrutar sesiones Google únicamente a Azure Functions con el token Firebase; si falta AI_BASE_URL, mostrar que el servicio administrado no está disponible sin ofrecer la conexión de Invitado.
- [x] Enrutar Invitado únicamente a un proveedor configurable compatible con OpenAI Chat Completions; guardar URL base, modelo y clave en un único registro de almacenamiento seguro del dispositivo.
- [x] Dejar la opción “Conecta tu IA de prueba para consultas reales” visible solo en el perfil Invitado. Para Google no aparece la opción de configurar una clave propia.
- [x] Añadir operaciones de texto, cuestionarios y análisis de imágenes/texto para la ruta Invitado. No se hace una llamada de prueba al guardar; los límites los determina el proveedor. PDF no está admitido en esta ruta directa.
- [x] Actualizar la documentación de configuración y separar la cuota Azure/Firestore de los límites del proveedor elegido por Invitado.

No se compiló el APK, no se ejecutaron pruebas ni análisis, no se desplegó Azure y no se configuraron ni guardaron claves del propietario. El código requiere validar ambos caminos en el teléfono y desplegar Azure antes de que la IA de las cuentas Google funcione.

### Norma añadida por la aclaración del propietario · 22/10/2026
La clave OpenAI de DraftAI solo reside en Azure y se usa mediante sesión Google autenticada; nunca se incluye en Flutter ni en APK. Las cuentas Google no muestran la configuración de IA de Invitado. Invitado solo usa su URL/modelo/clave propios, guardados en el almacén seguro local, y no accede al backend Azure con esa credencial.

## Publicación beta 4 · 22/10/2026

**Publicado:** [DraftAI 0.2.3-beta.4 · Android · Beta testing](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.2.3-beta.4), con `DraftAI-0.2.3-beta.4-android.apk` y `SHA256SUMS.txt`. Tag compilado: `v0.2.3-beta.4`, commit `40a25a8`.

Versión `0.2.3-beta.4+9`, APK de 85,863,143 bytes. Firma de lanzamiento nueva para este build; solo esquema APK v2 verificado. SHA-256 del APK: `a57c7cbdbdd9fc5bc5dbeaab8987ed9414d6561cc78c2927a2cdb903bf33b626`. La huella de firma y los pasos de configuración de Firebase están en `docs/CONFIGURATION.md`. Para las siguientes actualizaciones, conservar los archivos locales ignorados `android/draftai-release.jks` y `android/key.properties`.

Compilación `flutter build apk --release` completada. No se ejecutaron pruebas automatizadas, no se instaló el APK ni se probó en el teléfono. Al cambiar la firma, se requiere instalación limpia; registrar la SHA-1 de beta 4 y actualizar la configuración Firebase antes de usar Google Sign-In. El endpoint Azure sigue pendiente y la IA de Google se configurará para beta 5.

## Correcciones locales de exportación, edición y perfil · 22/10/2026

- [x] Reemplazar `android/app/google-services.json` por el archivo descargado más reciente; se verificó que es JSON válido, declara el paquete Android de DraftAI y contiene tres entradas OAuth.
- [x] Hacer cuadrado y adaptable al espacio de pantalla el recorte circular de la foto de perfil. El recorte se centra al abrir y conserva la resolución de origen disponible; el avatar usa una resolución de caché acorde a su tamaño en pantalla.
- [x] Añadir un botón de tabla visible en la barra de edición, insertar filas y columnas, editar la tabla y representarla como cuadrícula en el apunte.
- [x] Mostrar controles de esquina al seleccionar una imagen insertada, para cambiar su ancho y alineación.
- [x] En la previsualización PDF/Word, quitar el control global de tamaño; cada imagen se selecciona en la hoja para ajustar el tamaño, alineación y posición por arrastre.
- [x] Corregir exportación y copia TXT/Markdown: el texto queda en su orden y las imágenes se representan en línea como `<<nombre-del-archivo>>`, sin lista de adjuntos ni URI `content://` al copiar.
- [x] Mejorar el diálogo de fórmula LaTeX para previsualizar la fórmula y restaurar la selección original del editor al insertar.
- [x] Mantener el icono de nota y ubicar el control de selección al extremo derecho en la vista de lista.
- [x] Ajustar el paso de las líneas, cuadrícula y puntos al desplazamiento y estilo de escritura; ampliar traducciones al inglés para los diálogos, errores, exportación, preferencias, cuota y contenido de ayuda.

Comprobaciones realizadas: `dart format` en 18 archivos Dart; `git diff --check` sin errores; lectura del JSON de Firebase y comprobación del identificador de paquete. No se ejecutaron análisis estáticos, pruebas, emulador ni compilación APK. No se instaló en el teléfono ni se cambió GitHub. Pendiente: comprobar las interacciones y el acceso Google en el teléfono. Azure no está desplegado y esta modificación no genera un APK beta.
