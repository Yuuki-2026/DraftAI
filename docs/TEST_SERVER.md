# Servidor temporal de prueba

Las claves se conservan cifradas por Windows en el perfil local del propietario, fuera del repo. `server/local-start.ps1` las descifra solo para el proceso Node. Nunca copiarlas a Dart, al APK, a la release ni a los registros. La fuente original en Downloads pertenece al propietario y no se modifica.

## Iniciar
Desde el proyecto: `pwsh -NoProfile -File server/local-start.ps1`. Escucha únicamente en 127.0.0.1:8787. El túnel cloudflared publica ese servicio mediante HTTPS. Para detenerlo, cerrar los procesos del servidor y el túnel. No se instala un servicio de Windows. La URL cambia si se reinicia el túnel.

En el móvil: abrir un apunte → IA → Conectar IA de prueba; introducir URL HTTPS y código local. El código nunca se incluye en GitHub. Autoriza un máximo de cuatro dispositivos, con tokens separados guardados en el almacén seguro del teléfono y vencimiento de 24 horas. Puede actualizarse la URL sin recompilar.

## Modelos fijados y alcance
- Texto y validación de seguridad: Groq `openai/gpt-oss-20b`.
- Lectura fiel de imágenes: Groq `qwen/qwen3.8-27b`. Se marca texto ilegible, se separa transcripción/resumen y se confirma antes de guardar.
- NVIDIA queda como credencial cifrada de reserva; no hay cambio automático de proveedor o modelo.
- No es la API de OpenAI ni un ChatGPT Pro de pago. Esa integración queda para una fase posterior.

Disponibilidad verificada con GET /models y solicitudes pequeñas de texto/imagen. Referencias: https://console.groq.com/docs/models y https://console.groq.com/docs/vision.

## Límites del servidor
Gratis: dos operaciones por dispositivo y día. Prueba Pro autorizada: diez; el conmutador visual del APK no concede permisos del servidor. Día de cuota del servidor en UTC; el contador local es orientativo.

Máximo global: 60 llamadas al proveedor al día, incluidas las verificaciones de seguridad. Contadores persistentes y bloqueo de archivo; un reinicio no concede saldo nuevo y un contador dañado bloquea solicitudes. Dos operaciones simultáneas, cuatro intentos por dispositivo/minuto y seis intentos de conexión/minuto globales. Sin reintentos automáticos.

Texto: hasta 12000 caracteres de entrada, salida limitada a 1536 tokens (500 para validación). Imágenes: hasta cinco, máximo 8 MiB individual y 10 MiB el lote. Solo firmas PNG/JPEG/WebP válidas; ningún endpoint de chat, URL de proveedor o modelo configurable por el cliente. Los rechazos y fallos no habilitan llamadas ilimitadas. Cancelar la conexión evita continuar la cadena; una llamada ya procesada podría contar en el proveedor.

Estas barreras no sustituyen el límite de gasto de la cuenta del proveedor ni controlan otros usos de la misma clave. Este servidor es para pruebas de una instancia, no facturación o despliegue productivo distribuido.

## Autorizar lectura de imágenes de prueba
La autorización se realiza en esta computadora, nunca desde el cliente: `node server/test-devices.mjs list`, luego `node server/test-devices.mjs pro latest` para el último dispositivo conectado. `free latest` revoca esa autorización. El límite global sigue vigente. En la app se activa también la vista previa de Pro; no hay cobros.

Las notas permanecen locales. Solo se envía el material confirmado al servicio temporal y al proveedor. Cloudflare transporta las solicitudes; no recibe las claves del proveedor mediante la API de DraftAI. El servicio deja de estar disponible si se apaga la computadora o el túnel.
