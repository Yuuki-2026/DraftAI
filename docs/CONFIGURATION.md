# Configuración de servicios

## IA con tu clave

Abre **Perfil → Conectar IA** desde Invitado o desde una cuenta Google.

- **Proveedor preconfigurado.** Elige OpenAI, Claude o Gemini y pega tu clave. Los modelos configurados son `gpt-6-luna`, `claude-haiku-5-5` y `gemini-3.1-flash-lite`, respectivamente.
- **Servidor personalizado.** Ingresa la URL base HTTPS, el modelo y la clave de un proveedor compatible con Chat Completions.

«Probar y guardar» envía un mensaje breve de comprobación. El proveedor puede contarlo dentro de su cuota. Para OpenAI, la clave debe tener permiso para solicitar respuestas al modelo. Cada proveedor aplica sus tarifas, límites y condiciones de privacidad.

DraftAI guarda la conexión de cada perfil en el almacén seguro del teléfono. Cerrar la app conserva la conexión. Cerrar sesión o cambiar de cuenta Google elimina la clave local de la cuenta saliente. «Desconectar» permite borrar la clave del perfil activo.

El análisis directo admite texto e imágenes JPEG, PNG, WebP y GIF cuando el modelo permite ese formato. El límite es de 15 MB por solicitud. Para analizar un PDF, extrae primero su texto. Puedes editar, organizar, buscar y exportar apuntes sin configurar IA.

## Google y bóvedas locales

1. Habilita Authentication → Google en Firebase y registra el paquete Android **pe.edu.uandina.draft_ai**.
2. Registra la huella SHA-1 del certificado de la variante que vas a instalar. Las variantes de depuración y publicación pueden usar firmas distintas.
3. Guarda la configuración Android como `android/app/google-services.json`. Debe incluir un cliente OAuth web (`client_type: 3`).

Firebase Authentication identifica cada cuenta. Invitado y cada cuenta tienen una bóveda independiente cifrada en el teléfono. Si se confirma el traslado de apuntes de Invitado, DraftAI copia y verifica los apuntes, los adjuntos y el historial antes de limpiar esa biblioteca. Las bibliotecas se guardan localmente.

## Firma Android
La beta 5, compilación 11, usa el certificado de las versiones anteriores a la beta 4. Android requiere una instalación limpia si tienes beta 4. Desinstalar la beta 4 borra sus apuntes locales. Puedes probar en otro dispositivo y mantener la beta 4 instalada donde ya tienes tus apuntes.

La configuración local de Firebase incluye la firma de beta 4. Para validar Google en beta 5, registra la huella SHA-1 de la beta 5 y actualiza la configuración de Firebase. Invitado permite probar la biblioteca y conectar la IA con tu propia clave.

El almacén de firma y sus contraseñas están excluidos de Git. Conserva una copia privada.


## Copias locales
SQLite cifra los contenidos, no las fechas ni los identificadores. Las exportaciones y copias ZIP se entregan legibles por petición explícita del usuario. El ZIP contiene library.json y attachments/; no incluye credenciales ni la clave de cifrado. Actualmente puede recuperarse fuera de la app; no hay importador de copias ZIP en esta versión.

## Certificado público de beta 4
Añadir esta SHA-1 en Firebase → Configuración del proyecto → Tus apps → DraftAI Android → Huellas digitales SHA. Luego descargar el `google-services.json` actualizado y reemplazar `android/app/google-services.json` antes de compilar para habilitar Google Sign-In con esta firma.

SHA-1: `BA:91:5F:8D:C3:A4:5F:5C:A6:FD:39:BD:90:5C:10:03:7A:1D:80:3B`

SHA-256: `D3:4C:2B:F5:EF:AA:9A:5D:D3:AC:43:D4:4C:0B:FD:CA:C2:4F:DF:D1:C5:34:62:1B:10:2B:32:43:EB:71:5F:94`

### Certificado de beta 5 y versiones anteriores a beta 4

SHA-1: `57:6E:26:AB:21:54:B1:E6:BF:6F:0E:B1:6E:D9:28:5E:5C:1A:26:6E`

SHA-256: `35:78:18:AA:CA:9A:DB:9F:DC:D7:85:5D:C2:92:30:75:30:95:47:FF:C6:49:B5:87:C4:D1:1F:2F:50:68:32:2D`

Estos valores son públicos; no contienen la clave privada.
