# Configuración pendiente del propietario

## Qué funciona sin claves
El APK entra como invitado y permite crear, editar y organizar notas locales, formato enriquecido, imágenes, búsquedas, historial, papelera y exportación. Pro es una vista previa sin compras. El resumen demostrativo extrae frases localmente; la mejora demostrativa normaliza espacios. El OCR demostrativo muestra un formulario editable y declara que no leyó las imágenes.

## Google (opcional)
1. Crear un proyecto Firebase y habilitar Authentication → Google.
2. Registrar Android con paquete **pe.edu.uandina.draft_ai**. Añadir las huellas SHA-1/SHA-256 del certificado real de release (`keytool -list -v -keystore android/draftai-release.jks`, introduce la contraseña local; no compartirla).
3. Copiar `config/app.example.json` a `config/app.json` (ignorado por Git). Completar los identificadores de Firebase y el ID de cliente OAuth de tipo web en GOOGLE_SERVER_CLIENT_ID. Los identificadores Firebase son configuración pública, no una clave privada de IA.
4. Compilar: `flutter build apk --release --dart-define-from-file=config/app.json`.
El SDK de Firebase administra su sesión; no se persisten contraseñas ni tokens propios en SQLite. Google solo autentica y no sube la biblioteca. La biblioteca es de este dispositivo, independientemente de la sesión.

## Proveedor de IA futuro
Las claves privadas se colocan **en server/.env, nunca en config/app.json ni en Dart**. Se incluye un gateway de referencia para un proveedor compatible con Chat Completions. Luna y Jev no se han identificado mediante documentación/API oficial: no se promete que esos nombres sean compatibles. Completar AI_MODEL y AI_UPSTREAM_URL con los identificadores reales que indique el proveedor. No se fijan precios de modelos desconocidos.

1. `cd server`, `npm ci`, copiar `.env.example` a `.env`.
2. Configurar AI_API_KEY, AI_MODEL, AI_UPSTREAM_URL, GOOGLE_APPLICATION_CREDENTIALS (archivo privado de servicio Firebase fuera del repo) y FIREBASE_PROJECT_ID.
3. Para probar OCR con usuarios autorizados, añadir sus UID a DEMO_PRO_UIDS. El cliente no puede autoasignarse permisos del servidor.
4. Publicar el gateway detrás de HTTPS y limitar el acceso en el alojamiento. Ejecutar con Node **24.17.0**: `npm start`.
5. Añadir la URL HTTPS del gateway en AI_BASE_URL y recompilar el APK.

Contrato propio: POST v1/transform recibe `{text, action: summarize|improve}` y devuelve `{text}`. POST v1/analyze recibe archivos y nombres de carpetas/categorías; devuelve `{text, summary, title, topic, folderName, categoryName}`. El adaptador actual del gateway acepta imágenes JPEG/PNG/WebP; PDF permanece como adjunto, sin OCR remoto en este adaptador. Se puede añadir otro adaptador sin cambiar Domain/Presentation.

El gateway exige token Firebase, limita uso diario y rechaza contenido excesivo. La cuota de referencia está en memoria por instancia: para producción con múltiples instancias sustituirla por almacenamiento compartido, y reemplazar la lista demo por derechos de pago verificados. No hay pagos reales en esta entrega.

## Firma Android
La firma de esta entrega se conserva localmente en `android/draftai-release.jks`; las contraseñas están en `android/key.properties`, ambos ignorados por Git. Copiar ambos a un respaldo privado del propietario. Nunca adjuntarlos a una release. Se necesita la misma firma para actualizar una instalación existente.

## Copias locales
SQLite cifra los contenidos, no las fechas ni los identificadores. Las exportaciones y copias ZIP se entregan legibles por petición explícita del usuario. El ZIP contiene library.json y attachments/; no incluye credenciales ni la clave de cifrado. Actualmente puede recuperarse fuera de la app; no hay importador de copias ZIP en esta versión.
