# Plan de cuentas, almacenamiento y límites en GCP

Estado: diseño propuesto; todavía no se creó ni modificó ningún recurso de GCP.

## Situación actual del repositorio

- El inicio de sesión Google con Firebase Auth ya tiene una implementación, pero requiere la configuración Firebase de la aplicación. La biblioteca de notas sigue siendo local.
- La app usa un único archivo `draftai.sqlite` y una sola clave local `vault_key_v1`. Por eso, hoy no separa bóvedas por cuenta en el mismo teléfono.
- El gateway Node ya valida Firebase ID tokens y obtiene el `uid`. La app todavía se conecta al gateway de pruebas mediante URL y código.
- El límite escrito en el servicio es **2 operaciones diarias para Gratis y 10 para Pro**. El límite de 30 fue temporal en el servidor de pruebas entre el 16 y 17 de octubre de 2026; ya venció. El gateway actual también limita el presupuesto global a 60 llamadas del proveedor por día.
- El contador por usuario vive en memoria y el global en un archivo local. En GCP se deben persistir con transacciones, para que reinicios no reinicien el uso.
- El gateway recibe `AI_API_KEY` por variable de entorno. En producción la clave se leerá de Secret Manager con una identidad de VM de permisos mínimos; nunca irá en Flutter ni en Git.

## Arquitectura propuesta

1. **Identidad:** Firebase Authentication con Google entrega un ID token a la app. La app manda el token por HTTPS al gateway Node. El gateway verifica el token y toma el `uid` verificado; nunca acepta un UID enviado como dato confiable por el cliente.
2. **Notas y adjuntos:** Cloud Firestore guarda metadatos y cargas cifradas bajo `users/{uid}/...`; Cloud Storage guarda imágenes y archivos cifrados en `users/{uid}/...`. Las reglas comparan el UID autenticado con el UID de la ruta.
3. **IA:** el gateway existente corre en una VM de Compute Engine, detrás de HTTPS y un proxy inverso. Verifica el ID token, valida tamaño/acción, aplica cuota por UID y llama al proveedor. La API key de OpenAI se guarda en Secret Manager y solo la identidad de servicio de esa VM puede leerla. La app conoce la URL HTTPS, pero no la clave del proveedor ni un código de emparejamiento.
4. **Cuotas:** reemplazar `DailyQuota` en memoria por un contador transaccional de Firestore, indexado por UID y fecha. Mantener inicialmente Gratis 2/día y Pro 10/día y el presupuesto global de proveedor de 60/día. El estado Pro debe venir de una fuente administrada por servidor y no ser editable desde la app. Si se desea Pro 30/día, hay que decidirlo explícitamente antes de fijar las reglas; no es el límite vigente.
5. **Autorización del servidor:** el SDK Admin de Firebase omite las reglas de Firestore. Cada ruta de servidor que lea/escriba datos debe construir su ruta usando exclusivamente el UID del token ya verificado y limitar privilegios mediante IAM.

## Cifrado y propiedad de los datos

La bóveda local ya cifra cada payload con AES-GCM, pero su clave actual es única para la instalación. La siguiente versión debe tener una base local y una clave independientes por identidad: invitado y cada UID Google.

Para que ni la base de datos ni el servidor de DraftAI puedan descifrar una copia almacenada, el cifrado de notas y adjuntos debe ocurrir en el teléfono antes de subirlos. Cada cuenta genera una clave aleatoria de 256 bits; los datos usan AES-256-GCM con nonce nuevo y metadatos autenticados que incluyan UID e ID del objeto. Firestore/Storage reciben solo ciphertext. La clave local se protege en el almacén seguro del dispositivo.

Para recuperar notas en otro teléfono hace falta acordar cómo recuperar la clave: una frase/clave de recuperación que conserva el propietario o un enrolamiento explícito de dispositivos. No derivar la clave de la contraseña de Google ni del ID token. Una clave de Cloud KMS controlada por el backend puede proteger los datos frente a una copia de la base, pero el servicio con permiso de descifrado podría leerlos; por tanto, no equivale a cifrado exclusivo del propietario.

Las acciones de IA son una excepción visible: para resumir, mejorar, analizar o crear un cuestionario, la app enviará el contenido seleccionado por HTTPS al gateway, que lo remitirá al proveedor. No se registrará ese contenido en logs y la app debe avisar antes de enviarlo. La promesa de cifrado exclusivo del propietario debe explicar claramente este procesamiento temporal.

## Cambio de invitado a Google

Al elegir Google desde una biblioteca de invitado, mostrar una confirmación antes de mover datos:

- **Transferir apuntes a esta cuenta:** autenticarse, crear/recuperar la clave de la cuenta, descifrar y volver a cifrar en el teléfono, subir a la ruta del UID y comprobar cantidad e integridad. Conservar la bóveda invitada hasta verificar la subida; solo después ofrecer borrar la copia local.
- **No transferir:** mantener la bóveda invitada intacta y abrir la biblioteca propia de la cuenta Google. No copiar ni subir los datos. La app debe permitir volver al perfil invitado y evitar mezclar ambas bibliotecas.
- Si se cancela el inicio de sesión, no cambia el perfil ni la biblioteca.

La migración debe ser reanudable e idempotente: si pierde conexión, no duplicará notas y tampoco borrará el original.

## Etapas de implementación

1. **Cerrar decisiones:** región, presupuesto/alertas, si Pro será 10 o 30 por día y método de recuperación de claves. No pedir ni pegar secretos en el chat.
2. **Preparar GCP/Firebase:** proyecto, Google Auth, Firestore, Cloud Storage, Secret Manager y VM. Crear una identidad de servicio específica para la VM con los permisos mínimos; no exportar JSON de cuenta de servicio.
3. **Separar perfiles locales:** migración Drift para `ownerId` o archivos de base distintos, claves locales distintas y pruebas de no mezcla invitado/UID A/UID B.
4. **Sincronización cifrada:** formato versionado, cifrado en cliente, reglas Firestore/Storage por UID, subida reintentable y manejo de conflictos.
5. **Transferencia invitado:** consentimiento, copia, verificación y rollback ante fallo.
6. **Gateway de producción:** sustituir emparejamiento URL/código por Firebase ID token; persistir cuotas y presupuesto global; consultar el plan desde servidor; recuperar la key OpenAI desde Secret Manager; desactivar logs de contenido.
7. **Despliegue y endurecimiento:** HTTPS, puertos mínimos, SSH restringido/IAP, firewall, actualizaciones del SO, backups y alertas de gasto. Validar reglas con dos cuentas distintas, invitado y cuenta sin permiso Pro antes de publicar.

## Referencias oficiales

- [Firebase: verificar ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Firestore: reglas por UID](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Firestore: los SDK de servidor omiten reglas](https://firebase.google.com/docs/firestore/client/libraries)
- [Compute Engine: identidades de servicio para VM](https://docs.cloud.google.com/compute/docs/access/service-accounts)
- [Secret Manager: secretos para servicios](https://docs.cloud.google.com/secret-manager/docs/best-practices)
- [OpenAI: proteger API keys](https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety)
- [Cloud KMS: cifrado de sobre](https://docs.cloud.google.com/kms/docs/envelope-encryption)
