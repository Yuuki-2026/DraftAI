# Servidor temporal de prueba

Las claves se conservan cifradas por Windows en el perfil local del propietario, fuera del repo. `server/local-start.ps1` las descifra solo para el proceso Node. Nunca copiarlas a Dart, al APK, a la release ni a los registros. La fuente original en Downloads pertenece al propietario y no se modifica.

## Iniciar
Desde el proyecto: `pwsh -NoProfile -File server/local-start.ps1`. Escucha únicamente en 127.0.0.1:8787. El túnel cloudflared publica ese servicio mediante HTTPS. Para detenerlo, cerrar los procesos del servidor y el túnel. No se instala un servicio de Windows. La URL cambia si se reinicia el túnel.

En el móvil: abrir un apunte → IA → Conectar IA de prueba; introducir URL HTTPS y código local. El código nunca se incluye en GitHub. Autoriza un máximo de diez dispositivos, con tokens separados guardados en el almacén seguro del teléfono y vencimiento de 24 horas. Puede actualizarse la URL sin recompilar.

## Modelos fijados y alcance
- Gratis, texto: Groq `openai/gpt-oss-20b`.
- Pro autorizado, texto e imágenes: OpenAI `gpt-5-nano-2025-08-07`, versión fijada; no hay sustitución automática por modelos más caros. Acceso comprobado con /v1/models y una transformación real pequeña. Se usa razonamiento mínimo.
- Comprobaciones de seguridad antes/después: Groq `openai/gpt-oss-20b`, también para Pro. Por tanto el texto enviado a Pro se procesa en OpenAI y en Groq para la validación. No se envía material sin la confirmación del usuario en la app.
- Qwen queda como configuración de visión de reserva del flujo anterior; el endpoint de imágenes requiere Pro y selecciona OpenAI. NVIDIA queda como credencial cifrada de reserva, sin uso ni cambio automático.
- No hay Google ni pagos reales. La autorización de pruebas se administra localmente; cambiar el plan visual del APK no altera permisos del servidor.

Precio oficial de referencia del modelo Pro: input USD 0.05 y output USD 0.40 por millón de tokens; el razonamiento cuenta como output. La documentación lo marca como modelo antiguo, pero la cuenta conserva acceso. Fuentes oficiales: https://developers.openai.com/api/docs/models/gpt-5-nano y https://developers.openai.com/api/docs/pricing .

## Consolas en Windows
Abrir PowerShell 7. Primera pestaña: `cd C:\Users\LENOVO\Documents\dev\DraftAI`, después `pwsh -NoProfile -File server/local-start.ps1`. Segunda pestaña: `& "$env:USERPROFILE\.cache\draftai-tools\cloudflared.exe" tunnel --url http://127.0.0.1:8787 --no-autoupdate`. Conservar ambas abiertas; Ctrl+C detiene el proceso de esa pestaña. No iniciar otra instancia si el puerto ya está ocupado.

Para revisar disponibilidad, abrir `http://127.0.0.1:8787/health` en la computadora y la nueva URL HTTPS del túnel terminada en `/health` desde el móvil. `ready: true` indica que responde; `proReady: true` indica que se cargó la clave Pro, no sustituye una operación real.

El código vigente siempre está en `$env:USERPROFILE\.codex\.secrets\draftai\runtime\pair-code.txt`. Cambia al reiniciar el servidor. Los dispositivos ya autorizados conservan su token hasta su vencimiento; no necesitan volver a emparejarse si la URL sigue igual. Si cambia la URL del túnel, usar la nueva URL y el código actual en Conectar IA de prueba. La guía privada contiene la conexión vigente; no se publica en GitHub.

## Límites del servidor
Gratis: dos operaciones por dispositivo y día. Prueba Pro autorizada: diez; el conmutador visual del APK no concede permisos del servidor. Día de cuota del servidor en UTC; el contador local es orientativo.

Máximo global: 60 llamadas al proveedor al día, incluidas las verificaciones de seguridad. Contadores persistentes y bloqueo de archivo; un reinicio no concede saldo nuevo y un contador dañado bloquea solicitudes. Dos operaciones simultáneas, cuatro intentos por dispositivo/minuto y seis intentos de conexión/minuto globales. Sin reintentos automáticos.

Texto: hasta 12000 caracteres de entrada, salida limitada a 1536 tokens en Gratis y 4096 en Pro, incluyendo razonamiento (500 por comprobación de seguridad). Fuentes: grupos de hasta cinco, máximo 8 MiB individual y 10 MiB por grupo. El APK admite hasta 20 fuentes y 60 MiB totales; cada grupo consume una acción. PDF de hasta 12 páginas, TXT/MD UTF-8 y PNG/JPEG/WebP. La salida de extracción tiene un máximo de 8192 tokens y señala lectura parcial cuando corresponde. Solo firmas PNG/JPEG/WebP válidas; ningún endpoint de chat, URL de proveedor o modelo configurable por el cliente. Los rechazos y fallos no habilitan llamadas ilimitadas. Cancelar la conexión evita continuar la cadena; una llamada ya procesada podría contar en el proveedor.

Estas barreras no sustituyen el límite de gasto de la cuenta del proveedor ni controlan otros usos de la misma clave. Este servidor es para pruebas de una instancia, no facturación o despliegue productivo distribuido.

## Autorizar lectura de imágenes de prueba
La autorización se realiza en esta computadora, nunca desde el cliente: `node server/test-devices.mjs list`, luego `node server/test-devices.mjs pro latest` para el último dispositivo conectado. `free latest` revoca esa autorización. El límite global sigue vigente. La app consulta los permisos reales del servidor y sincroniza el plan; no hay cobros.

Las notas permanecen locales. Solo se envía el material confirmado al servicio temporal y al proveedor. Cloudflare transporta las solicitudes; no recibe las claves del proveedor mediante la API de DraftAI. El servicio deja de estar disponible si se apaga la computadora o el túnel.

## Conexión en 0.2.2
El código Gratis está en `runtime/pair-code.txt`; el código Pro privado está en `runtime/pro-code.txt`, bajo la carpeta privada indicada arriba. Ambos cambian al reiniciar. El código Pro autoriza directamente pruebas de lectura de fuentes; no compartir públicamente. Reconectar al mismo servidor renueva el token y conserva permisos vigentes y consumo, sin ocupar otra plaza. `/v1/status` exige el token del dispositivo y devuelve permisos, modelo y acciones restantes. Las autorizaciones del operador sobreviven a nuevas conexiones.

La clasificación recibe solo identificadores y títulos de carpetas/apuntes, además de las fuentes elegidas; no recibe el cuerpo de los apuntes existentes. Cada propuesta se revisa antes de guardarse. Material no académico se marca para revisión manual. El límite de cinco es una decisión de esta app, no un límite universal de OpenAI.

## Análisis académico actualizado
Gratis usa Groq openai/gpt-oss-20b para mejorar selecciones y resumir (2 acciones/día). Pro usa gpt-5-nano-2025-08-07 y permite fuentes (10 acciones/día). NVIDIA no está activo como proveedor alternativo: no se hacen llamadas ni cambios automáticos de proveedor. Hasta 10 conexiones de prueba simultáneamente autorizadas; presupuesto global de 60 llamadas/día conservado. El resumen explica conceptos del contenido en español; las fuentes no académicas o ilegibles no reciben destino.
