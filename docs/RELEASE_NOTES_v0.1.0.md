# DraftAI 0.1.0 para Android

Primera entrega instalable del proyecto DS II. APK firmado para Android 8.0 (API 26) o superior; compilado con Flutter 3.47.2 / Dart 3.13.2 y target Android API 36.

## Incluye
- Notas locales con formato enriquecido, carpetas, categorías, temas y colores.
- Creación visible desde Inicio y carpetas; autoguardado y guardado explícito.
- Imágenes y cámara, importación de archivos y texto, revisión por lote.
- Búsqueda por título, tema y contenido; voz según disponibilidad del dispositivo.
- Lectura, historial persistente, restauración y papelera.
- Exportación PDF, Word, texto y Markdown; copia ZIP local.
- Contenidos e imágenes cifrados con AES-GCM y clave en el almacén seguro del sistema.
- Diseño oscuro basado en el mockup, puntos de quiebre y soporte de texto ampliado.

## Servicios y demostraciones
Funciona como invitado sin claves. Google requiere configurar el proyecto Firebase. La IA remota requiere desplegar el gateway y configurar el proveedor; sin ello se utiliza un modo demostrativo identificado. Gratis adjunta imágenes sin OCR; Pro es una vista previa sin cobros. El OCR demostrativo **no extrae texto de las imágenes**. No existe sincronización entre dispositivos ni pagos reales.

La configuración y la ubicación de cada credencial están en [docs/CONFIGURATION.md](https://github.com/Yuuki-2026/DraftAI/blob/main/docs/CONFIGURATION.md). Luna y Jev permanecen como nombres futuros pendientes de identificar mediante documentación oficial.

## Validación
27 pruebas locales (dominio, datos, adaptadores, exportación e interfaz adaptable) y 3 pruebas del gateway. Flujo completo de invitado, edición, reapertura, papelera/restauración y Pro comprobado en emulador Android 14 (API 34). PDF renderizado y revisado. APK de release verificado e instalado para comprobar arranque y persistencia.

El mínimo API 26 está declarado; Android 8 no se ha ejecutado en un dispositivo físico. iOS 15 está preparado como plataforma futura y no se ha compilado ni validado en macOS.

Adjuntos: APK firmado y SHA256SUMS.txt. Los certificados privados de firma y las claves no se incluyen.
