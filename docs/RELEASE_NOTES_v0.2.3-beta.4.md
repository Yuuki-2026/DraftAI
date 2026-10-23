DraftAI · Beta de pruebas

- Inicio de sesión con Google mediante Firebase y bóvedas cifradas independientes por cuenta; traslado opcional de Invitado con verificación.
- Exportación con vista previa, personalización y exportación de varios apuntes en un documento o en archivos separados. TXT y Markdown incluyen el contenido y muestran marcadores para las imágenes.
- Mejoras de edición y lectura: imágenes redimensionables y alineables, tablas editables, fórmulas legibles, estilos de página y formato persistente de color y resaltado.
- Perfil, preferencias, creación de apuntes y clasificación de imágenes actualizados. Invitado puede configurar un proveedor de IA propio.
- Preparación de Azure Functions para IA con Google. El endpoint todavía no está desplegado ni configurado; la IA de cuentas Google queda pendiente de la beta 5.

Esta beta usa una firma nueva: desinstala la versión anterior antes de instalarla; esto borra las notas locales. Para iniciar sesión con Google, registra en Firebase la SHA-1 `BA:91:5F:8D:C3:A4:5F:5C:A6:FD:39:BD:90:5C:10:03:7A:1D:80:3B` y usa el `google-services.json` actualizado. Las notas de esta versión se guardan cifradas en el teléfono, sin sincronización ni respaldo en la nube. Android 8.0 o superior. Esta versión beta puede contener errores.
