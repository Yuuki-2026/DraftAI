# DraftAI 0.2.0 - Android, versión de prueba

Notas con imágenes intercaladas en la posición del cursor, galería deslizable con zoom y PDF compacto que se abre al pulsarlo. Importación de un lote a una nota existente o nueva, con elección de la posición antes de insertar. Exportaciones PDF/Word respetan el orden de texto e imágenes y los encabezados.

Interfaz del colaborador integrada: carpetas con color y contraste, selector HEX/tono/espectro, vistas previas reales en Recientes, formularios de organización, selección individual/múltiple y papelera. Idioma Español/Inglés conectado y textos de la interfaz principal traducidos. Lectura con IA central y acciones secundarias en el menú.

La instalación inicial está vacía. Perfil → Biblioteca de prueba carga 20 notas ficticias con imágenes y PDF; puede eliminar solo los ejemplos. Las notas de versiones anteriores se conservan.

## IA de prueba
Conexión por dispositivo a un servidor HTTPS temporal, sin Google. Texto: Groq `openai/gpt-oss-20b`; imágenes: `qwen/qwen3.8-27b`, disponible para pruebas Pro autorizadas por el operador. Google y pagos reales no están implementados en esta entrega; los planes son demostrativos.

Solo mejora y resumen de apuntes y lectura de imágenes, con revisión antes de aplicar. No ofrece chat libre. Validación de entrada/salida, avisos ante solicitudes dañinas, cuotas por dispositivo y un máximo global persistente de 60 llamadas al proveedor/día. Las claves privadas están fuera del repositorio y del APK.

El acceso real a IA requiere que la computadora y el túnel del propietario estén encendidos y conectar con el código privado. No se publica ese código en esta release. Sin conexión se conserva el modo demostrativo identificado. Detalles en [TEST_SERVER.md](https://github.com/Yuuki-2026/DraftAI/blob/main/docs/TEST_SERVER.md).

## Verificación
23 pruebas del bloque principal y 6 del servidor aprobadas. Solicitudes reales pequeñas: resumen correcto, solicitud dañina bloqueada, cuota Gratis aplicada y lectura de una imagen sintética con título/resumen. Analizador estático sin hallazgos. El bloque visual del colaborador se revisó por código; a petición del propietario no se ejecutó su matriz de pruebas ni se tomaron capturas nuevas.

Android mínimo 8.0/API 26, target 36. Flutter 3.47.2, Dart 3.13.2 y Java 17. iOS 15 preparado, sin validación en macOS. APK firmado con el certificado existente y archivo SHA256SUMS.txt. Instalación como actualización y arranque comprobados en Android 14/API 34; revisión del APK sin coincidencias con las claves de proveedor facilitadas. La revisión visual completa y las pruebas funcionales en un teléfono físico quedan pendientes de esta entrega de prueba.
