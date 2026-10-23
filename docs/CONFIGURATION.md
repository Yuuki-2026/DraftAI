# Configuración de servicios

## API de IA en Azure
La API de producción se prepara como Azure Functions. La app envía el token de Firebase Authentication de la cuenta Google activa; el servidor verifica el UID, controla el consumo diario en Firestore y llama a OpenAI. La clave de OpenAI y la credencial administrativa de Firebase se configuran en Azure Key Vault, nunca en Flutter, el APK ni el repositorio.

Consulta [AZURE_DEPLOYMENT.md](../server/AZURE_DEPLOYMENT.md) para los ajustes del servidor. El límite inicial es 30 operaciones diarias por cuenta Google, configurable en el servidor; hay también un tope global de solicitudes al proveedor. No se guarda el contenido de los apuntes en la API. Solo se envía el contenido seleccionado para la acción solicitada.

El acceso de las cuentas Google es solo por el backend administrado. Si la URL de Azure no está configurada, la app muestra que el servicio aún no está disponible y no cae a la clave del perfil Invitado.

## IA propia en modo Invitado
Invitado puede configurar una URL HTTPS, el identificador de modelo y una clave API de un proveedor compatible con OpenAI Chat Completions. La configuración se guarda en el almacén seguro del teléfono y solo se usa mientras el perfil activo sea Invitado. La app envía las solicitudes directamente al endpoint elegido; ese proveedor fija sus propios límites, disponibilidad y condiciones de privacidad. La integración no promete que todos los planes gratuitos sean permanentes ni compatibles.

El formulario pide la URL base del endpoint, no la clave dentro de la URL. No se hacen solicitudes de prueba al guardar, para evitar consumir cuota; el proveedor y la clave se comprueban en la primera operación real. El flujo invitado admite texto e imágenes JPEG/PNG/WebP/GIF hasta 15 MB por solicitud; los PDF requieren extraer o exportar su texto. Las credenciales de Invitado no se comparten con Azure ni con las cuentas Google.

## Qué funciona sin claves
El APK permite crear, editar y organizar notas locales, formato enriquecido, imágenes, búsquedas, historial, papelera y exportación en modo invitado. La IA de Invitado requiere una clave del proveedor que el propio usuario elija; la IA administrada de las cuentas Google requiere el backend de Azure.

## Google y bóvedas locales
1. En Firebase, habilitar Authentication → Google y registrar la app Android con paquete **pe.edu.uandina.draft_ai**.
2. Añadir la huella SHA-1 del certificado que firma la variante que se instalará. Una APK debug y una APK release pueden tener huellas distintas.
3. Descargar el archivo de configuración Android y guardarlo con el nombre exacto `android/app/google-services.json`. Debe incluir un cliente OAuth web (`client_type: 3`).
4. El proyecto aplica Google Services Gradle Plugin y carga esa configuración nativa. La URL pública de Azure se configura aparte con AI_BASE_URL al preparar la variante conectada; nunca se añade una clave privada a Dart.

Firebase Authentication identifica al usuario con su UID. Invitado y cada UID usan archivos de base y claves AES-GCM distintas; las claves se protegen con el almacén seguro del sistema. Al elegir mover notas de Invitado, DraftAI copia y vuelve a cifrar notas, adjuntos e historial en la bóveda del UID, verifica que se puedan leer y luego limpia Invitado. Si no se acepta, no mezcla los datos. Una interrupción deja el original de Invitado y permite reintentar.

Esto aún es almacenamiento cifrado **en el teléfono**: no hay Cloud Storage ni sincronización de notas a otros dispositivos. Firestore se usa en la API únicamente para contadores de cuota; no guarda los apuntes.

## Configurar el APK para la API
Después de desplegar Azure Functions, recompilar la app con AI_BASE_URL apuntando a la URL HTTPS de la Function App y terminando en /api/. En esa variante, la IA se conecta automáticamente con la sesión Google. AI_BASE_URL no incluye ninguna clave. Invitado conserva su configuración de proveedor, aislada en el teléfono y separada de la ruta Google.

Contrato: POST v1/transform recibe {text, action: summarize|improve|quiz}; resumen/mejora devuelven {text} y cuestionarios devuelven {questions: [{question, options, answerIndex, explanation}]}. POST v1/analyze procesa fuentes dentro de los límites del servicio. La API requiere una cuenta Google, rechaza entradas inválidas o excesivas y no devuelve credenciales del proveedor.

## Firma Android
La beta 4 usa una firma nueva conservada localmente en `android/draftai-release.jks`; sus contraseñas están en `android/key.properties`. Ambos archivos están ignorados por Git. Guardar una copia privada y conservarlos para firmar también la beta 5; nunca adjuntarlos a una release. La beta 4 no actualiza instalaciones firmadas con la clave anterior: requiere desinstalar la versión previa, lo cual borra sus datos locales.

## Copias locales
SQLite cifra los contenidos, no las fechas ni los identificadores. Las exportaciones y copias ZIP se entregan legibles por petición explícita del usuario. El ZIP contiene library.json y attachments/; no incluye credenciales ni la clave de cifrado. Actualmente puede recuperarse fuera de la app; no hay importador de copias ZIP en esta versión.

## Certificado público de beta 4
Añadir esta SHA-1 en Firebase → Configuración del proyecto → Tus apps → DraftAI Android → Huellas digitales SHA. Luego descargar el `google-services.json` actualizado y reemplazar `android/app/google-services.json` antes de compilar para habilitar Google Sign-In con esta firma.

SHA-1: `BA:91:5F:8D:C3:A4:5F:5C:A6:FD:39:BD:90:5C:10:03:7A:1D:80:3B`

SHA-256: `D3:4C:2B:F5:EF:AA:9A:5D:D3:AC:43:D4:4C:0B:FD:CA:C2:4F:DF:D1:C5:34:62:1B:10:2B:32:43:EB:71:5F:94`

Huellas históricas de la release 0.1.0:

SHA-1: `57:6E:26:AB:21:54:B1:E6:BF:6F:0E:B1:6E:D9:28:5E:5C:1A:26:6E`

SHA-256: `35:78:18:AA:CA:9A:DB:9F:DC:D7:85:5D:C2:92:30:75:30:95:47:FF:C6:49:B5:87:C4:D1:1F:2F:50:68:32:2D`

Estos valores son públicos; no contienen la clave privada.
