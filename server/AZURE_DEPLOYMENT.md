# Guía de Azure para DraftAI

Esta guía es para desplegar el backend de IA y preparar su primera prueba desde la app. Está escrita para la persona que administrará Azure, Firebase y la clave del proveedor.

## 1. Resultado esperado

- Las cuentas que inician sesión con Google usan la API de DraftAI alojada en Azure Functions.
- Azure valida el Firebase ID token y rechaza solicitudes sin una sesión Google válida.
- La clave de OpenAI y la credencial de Firebase permanecen en Azure Key Vault. Nunca van en Flutter, en el APK, en `google-services.json` ni en Git.
- El servidor registra solamente cuotas de uso en Cloud Firestore; no guarda apuntes ni imágenes. El contenido seleccionado se envía a OpenAI para procesarlo.
- Cada cuenta Google tiene un límite inicial de 30 operaciones exitosas por día. El límite global inicial es de 900 llamadas al proveedor por día. El invitado sigue usando el proveedor que configure localmente y no consume la cuota de Azure.

El código está en `server/`. Usa el modelo de programación Node.js v4 de Azure Functions y requiere Node.js 24, que debe estar disponible para la región Flex Consumption elegida. Microsoft indica que Node 24 requiere Azure Functions Runtime 4.25 o posterior; confirma que la región seleccionada ofrece Node 24 antes de crear la Function App. [Referencia Node.js de Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-node?tabs=v4) · [Versiones disponibles en Flex Consumption](https://learn.microsoft.com/en-us/azure/azure-functions/migration/migrate-plan-consumption-to-flex)

## 2. Accesos y materiales necesarios

La persona que lo despliegue necesita:

1. Una suscripción Azure activa con permisos para crear recursos, Function Apps, Key Vault y asignaciones de roles. Si aún no existe, revisar [las opciones actuales de cuenta Azure](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account): la prueba gratuita está sujeta a elegibilidad y hoy ofrece crédito por 30 días; al terminar, los recursos se deshabilitan si no se cambia a pago por uso. La verificación de facturación/tarjeta puede ser requerida por Microsoft.
2. Acceso de administrador al proyecto Firebase `draftai-6a5aa` para crear Firestore, reglas y una cuenta de servicio.
3. Una clave API de un proyecto OpenAI con facturación habilitada y acceso a un modelo que admita Chat Completions y respuestas JSON. Para analizar imágenes, el modelo de visión también debe aceptar imágenes. La clave debe crearla y guardarla su propietario; no se debe enviar por chat ni incluir en archivos del repositorio.
4. En el equipo de despliegue: Node.js 24, npm, Azure CLI y Azure Functions Core Tools v4 actualizado. Los comandos `az` y `func` deben abrir en PowerShell. La publicación de Core Tools despliega el proyecto local a una Function App existente. [Publicar con Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v4%2Cmacos%2Ccsharp%2Cportal%2Cbash)

## 3. Preparar Firebase y Firestore

1. En Firebase Console, selecciona el proyecto **DraftAI** (`draftai-6a5aa`) y confirma en **Authentication → Método de acceso** que **Google** esté habilitado.
2. Abre **Compilación → Firestore Database** y crea la base de datos predeterminada en edición **Standard**, modo **Producción**. Elige una región cercana al servicio y a los usuarios; revisa la ubicación antes de confirmar.
3. En **Firestore → Reglas**, publica las reglas del archivo `firestore.rules` de este repositorio. Deniegan lectura y escritura desde aplicaciones cliente. El Admin SDK del servidor usa IAM y opera de forma privilegiada, por lo que no necesita abrir reglas al teléfono. [Crear Firestore y configurar reglas](https://firebase.google.com/docs/firestore/quickstart)

   Si se despliega desde la raíz del repositorio con Firebase CLI ya instalado y autenticado, también se puede ejecutar:

   ```powershell
   firebase deploy --only firestore:rules --project draftai-6a5aa
   ```

4. En Google Cloud Console del mismo proyecto, entra en **IAM y administración → Cuentas de servicio** y crea una cuenta dedicada, por ejemplo `draftai-azure-api`.
5. Asígnale el rol **Cloud Datastore User** (`roles/datastore.user`), necesario para leer y escribir los contadores de Firestore. No le asignes **Owner**, **Editor** ni roles de administración completa. [Roles IAM de Firestore](https://docs.cloud.google.com/firestore/docs/security/iam)
6. En la cuenta de servicio, crea una clave JSON y guárdala temporalmente en un lugar privado. El Admin SDK necesita una cuenta de servicio para verificar Firebase ID tokens. La clave JSON es secreta: no la subas al repositorio, no la envíes a otra persona y no la pegues en la app. [Verificar Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens) · [Configurar Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)

**Alcance de IAM:** `roles/datastore.user` da acceso de lectura y escritura a los datos de Firestore del proyecto, mientras que el código de DraftAI solo usa las colecciones `draftai_ai_usage` y `draftai_system`. Mantén ese proyecto/base de datos dedicado a DraftAI. Si ya contiene otros datos privados, detén el despliegue y separa primero la base de datos o el proyecto; no concedas este rol a una base con datos que el servicio no debe poder leer.

## 4. Crear los recursos de Azure

1. En [portal.azure.com](https://portal.azure.com), abre **Crear un recurso → Function App → Crear**.
2. Selecciona una suscripción y crea un grupo de recursos, por ejemplo `rg-draftai`. El nombre de Function App debe ser único globalmente; usa uno como `draftai-api-<iniciales>`.
3. Selecciona **Flex Consumption**, sistema operativo **Linux**, runtime **Node.js 24** y una región que ofrezca Node 24 en Flex Consumption. El portal filtra las combinaciones no disponibles. Si la región elegida no ofrece Node 24, cambia de región antes de continuar; `server/package.json` requiere Node 24.
4. Deja **Always ready instances** en `0` para evitar instancias permanentemente activas. Crea o selecciona una cuenta de almacenamiento para Functions y habilita **Application Insights**. Conserva los valores que Azure genere para Storage y Application Insights.
5. Crea un **Key Vault** en la misma suscripción, preferentemente en la misma región. Usa permisos de acceso basados en roles (RBAC).

Flex Consumption cobra según recursos y ejecuciones y aún puede haber cargos de almacenamiento y telemetría. Crea un presupuesto y alertas de coste para la suscripción o el grupo de recursos. Las alertas notifican; no detienen automáticamente el consumo. [Crear alertas de presupuesto](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)

## 5. Guardar las credenciales en Key Vault

En Key Vault, abre **Objetos → Secretos → Generar/Importar** y crea estos secretos:

| Nombre del secreto | Valor |
| --- | --- |
| `draftai-openai-api-key` | La clave API del proyecto OpenAI de DraftAI |
| `draftai-firebase-service-account-json` | El contenido íntegro del archivo JSON de la cuenta de servicio Firebase |

No agregues comillas envolventes al JSON. Una vez confirmado que el secreto se guardó, elimina la copia temporal del archivo JSON de la carpeta Descargas y de la papelera. No muestres los valores en capturas ni en el historial de PowerShell.

### Dar acceso de lectura a la Function App

1. Abre la Function App → **Identidad → Asignada por el sistema**, actívala y guarda. Copia el nombre de la identidad que aparece como activa.
2. Abre Key Vault → **Control de acceso (IAM) → Agregar asignación de roles**.
3. Asigna **Key Vault Secrets User** a la identidad administrada de esa Function App. No asignes el rol a todos los usuarios ni a la identidad personal del desarrollador.
4. En la Function App, abre **Configuración → Variables de entorno / Configuración** y agrega estas opciones:

   | Nombre | Valor |
   | --- | --- |
   | `FIREBASE_PROJECT_ID` | `draftai-6a5aa` |
   | `FIREBASE_SERVICE_ACCOUNT_JSON` | `@Microsoft.KeyVault(SecretUri=https://<NOMBRE-DEL-VAULT>.vault.azure.net/secrets/draftai-firebase-service-account-json/)` |
   | `AI_API_KEY` | `@Microsoft.KeyVault(SecretUri=https://<NOMBRE-DEL-VAULT>.vault.azure.net/secrets/draftai-openai-api-key/)` |
   | `AI_MODEL` | ID exacto de un modelo habilitado en el proyecto OpenAI que acepte Chat Completions y modo JSON |
   | `AI_VISION_MODEL` | ID de un modelo habilitado que también acepte imágenes; déjalo vacío solo si no se probará análisis de imágenes |
   | `AI_DAILY_LIMIT` | `30` |
   | `AI_GLOBAL_DAILY_LIMIT` | `900` |
   | `AI_QUOTA_TIME_ZONE` | `America/Lima` |
   | `FUNCTIONS_WORKER_RUNTIME` | `node` |

   Reemplaza `<NOMBRE-DEL-VAULT>` por el nombre real del Key Vault, sin los signos `< >`. Las referencias versionless a Key Vault tienen este formato. [Referencias de Key Vault para App Service y Functions](https://learn.microsoft.com/en-gb/azure/app-service/app-service-key-vault-references)

5. No borres `AzureWebJobsStorage` ni la cadena de Application Insights creadas al crear la Function App. En Flex Consumption no agregues `FUNCTIONS_EXTENSION_VERSION`; ese plan administra el runtime 4.x y no admite fijar esa opción. [Versiones del runtime Functions](https://learn.microsoft.com/en-us/azure/azure-functions/set-runtime-version)
6. Guarda los ajustes y reinicia la Function App. En la configuración, confirma que ambas referencias de Key Vault aparecen resueltas. Si aparece `AccessToKeyVaultDenied`, revisa la identidad y el rol **Key Vault Secrets User**.

## 6. Publicar el backend

Desde PowerShell, en el equipo que tenga este repositorio actualizado:

```powershell
az login
az account show --query "{subscription:name,id:id}" --output table
az account set --subscription "<ID_DE_LA_SUSCRIPCION>"
node --version
func --version
Set-Location D:\Mockup\DraftAI\server
npm ci
func azure functionapp publish <NOMBRE_DE_LA_FUNCTION_APP>
```

Antes de publicar, confirma que `node --version` muestre `v24.x` y que `func --version` sea Core Tools v4 actualizado. No crees `local.settings.json` con secretos para esta publicación. El comando se ejecuta dentro de `server/` y despliega el `host.json`, `package.json` y código de esta API.

Al terminar, abre la Function App → **Funciones** y confirma que aparece `draftaiApi`. La URL pública base que se usará en la aplicación tendrá esta forma:

```text
https://<NOMBRE_DE_LA_FUNCTION_APP>.azurewebsites.net/api/
```

No le agregues una Function key ni una clave OpenAI a esta URL.

## 7. Pruebas del servicio

### A. Comprobar que la ruta está publicada y protegida

En PowerShell, reemplaza el nombre por el de la Function App:

```powershell
$api = "https://<NOMBRE_DE_LA_FUNCTION_APP>.azurewebsites.net/api"
curl.exe -i "$api/v1/status"
```

Sin un Firebase ID token, la respuesta esperada es **HTTP 401** con el código `auth_required`. Eso demuestra que la ruta está viva y exige autenticación. **HTTP 404** indica URL/ruta incorrecta; **HTTP 503** indica configuración faltante, referencia Key Vault sin resolver o Firestore/cuenta de servicio sin configurar.

### B. Probar desde DraftAI con una cuenta Google

Después de que Azure esté desplegado, la app necesita compilarse con la URL de arriba. El responsable de la app puede generar el APK de prueba desde la raíz del proyecto con:

```powershell
flutter build apk --debug --dart-define=AI_BASE_URL=https://<NOMBRE_DE_LA_FUNCTION_APP>.azurewebsites.net/api/
```

No compiles ese APK antes de que la persona de Azure confirme el despliegue y entregue la URL pública. No se necesita volver a crear ni enviar la clave de OpenAI para esta compilación.

En el APK de prueba:

1. Inicia sesión con una cuenta Google real.
2. Abre **Perfil → Conectar IA** y actualiza la conexión. Debe aparecer el modelo configurado y el límite `30`; inicialmente deben quedar `30` operaciones.
3. Crea o usa un apunte breve de prueba y solicita un resumen. Debe recibirse una respuesta y, al actualizar la conexión, debe quedar una operación menos.
4. Si `AI_VISION_MODEL` está configurado, analiza una imagen de prueba. Debe completar el análisis sin almacenar la imagen en Azure.
5. Si puedes, vuelve a iniciar en modo Invitado y confirma que la API de Azure no se usa: el invitado mantiene su proveedor propio.

No pruebes enviando claves o ID tokens por chat, capturas, correo o tickets. Para revisar contadores, usa Firebase Console → Firestore: el backend crea un documento por usuario con UID hasheado en `draftai_ai_usage` y un contador global en `draftai_system/provider_usage`.

### C. Revisar errores sin exponer secretos

En Azure Portal, revisa **Function App → Monitor** y **Application Insights → Logs**. Confirma ejecuciones correctas y revisa errores de autenticación, Firestore, Key Vault o OpenAI. No escribas en logs la clave API, la cuenta de servicio, el Firebase ID token ni el texto/imágenes de los apuntes.

Si hay un error:

- `401 auth_required`: el cliente no envió un Firebase ID token válido o venció la sesión.
- `403 google_account_required`: la sesión no usa el proveedor `google.com`.
- `503 server_configuration`: revisa `FIREBASE_PROJECT_ID` y la referencia a la credencial Firebase.
- `503 provider_configuration`: revisa que `AI_API_KEY` y `AI_MODEL` estén configurados y que Key Vault los resuelva.
- `503 quota_unavailable` o `budget_unavailable`: revisa la creación de Firestore, el proyecto Firebase y el rol IAM de la cuenta de servicio.
- `429 daily_limit`: se llegó a 30 operaciones de esa cuenta ese día.
- `429 global_limit`: se llegó al máximo global de 900 llamadas al proveedor ese día.
- `502 provider_unavailable`: revisa la clave, saldo, permisos y disponibilidad del modelo OpenAI.

El límite de 900 es un máximo de llamadas, no un presupuesto monetario. El coste depende del modelo y del volumen de tokens. Controla el consumo por separado en Azure Cost Management y en el proyecto OpenAI.

## 8. Entrega de la persona que lo despliega

Al terminar, debe devolver únicamente:

1. Nombre y región de la Function App.
2. La URL pública base terminada en `/api/`.
3. Confirmación de que las dos referencias de Key Vault aparecen resueltas.
4. Resultado del smoke test sin token: `401 auth_required`.
5. Confirmación de que Firestore está creado, las reglas cliente están publicadas y el rol de la cuenta de servicio quedó configurado.

No debe devolver ni adjuntar la clave OpenAI, el JSON de cuenta de servicio, contraseñas, tokens Firebase ni una captura donde se vean secretos.

## 9. Notas de seguridad y facturación

- La Function usa `authLevel: anonymous` deliberadamente: una Function key incluida en una app móvil se podría extraer. Cada operación se valida con Firebase Authentication y se acepta únicamente `google.com`.
- El API no recibe una clave OpenAI del usuario ni la devuelve al cliente. La clave compartida se queda en Key Vault. La app Invitado mantiene la conexión independiente que configure su usuario.
- El backend actual no almacena notas ni crea una copia cifrada de ellas. Solo administra cuotas. El almacenamiento/sincronización de apuntes por cuenta requiere un trabajo separado.
- La API limita el uso por cuenta y globalmente, pero esos límites no equivalen a un tope de gasto. Configura alertas de costes en Azure y vigila el uso en OpenAI. Los presupuestos de Azure envían alertas; no detienen el consumo automáticamente.
- Revisa el coste de Firestore, Azure Functions, Storage, Application Insights y OpenAI por separado. Los precios y cuotas gratuitas pueden variar según región, plan y cuenta.

## Documentación oficial

- [Azure Functions Node.js](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-node?tabs=v4)
- [Flex Consumption](https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-how-to)
- [Publicación con Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v4%2Cmacos%2Ccsharp%2Cportal%2Cbash)
- [Referencias de Key Vault](https://learn.microsoft.com/en-gb/azure/app-service/app-service-key-vault-references)
- [Alertas de costes de Azure](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Crear Firestore](https://firebase.google.com/docs/firestore/quickstart)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Verificación de Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [IAM para Firestore](https://docs.cloud.google.com/firestore/docs/security/iam)
