# DraftAI · Beta

Apuntes con texto, imágenes y archivos, organizados en carpetas. Edita con formato, añade temas y exporta tus notas.

**Versión en pruebas; puede contener errores.** Android 8.0 o superior.

[Descargar beta 5 para Android](https://github.com/Yuuki-2026/DraftAI/releases/tag/v0.2.3-beta.5)

**Instalación limpia.** La beta 5 usa una firma distinta de la beta 4. Para probarla, usa un dispositivo sin beta 4. Desinstalar la beta 4 borra sus apuntes locales.

- Guardado manual con aviso al salir.
- Temas con fecha y selección de contenido para resúmenes.
- Mejora de texto y organización de fuentes con IA.
- Notas cifradas en el dispositivo.

Google inicia sesión con Firebase Authentication. Cada cuenta y el perfil Invitado usan una bóveda cifrada local independiente. Al entrar con Google, puedes trasladar los apuntes de Invitado tras confirmar; se verifica la copia antes de retirar el original. Las notas todavía no se sincronizan con la nube y permanecen en este teléfono. La app empieza vacía; Perfil → Biblioteca de prueba permite cargar ejemplos opcionales.

En **Perfil → Conectar IA**, Invitado y las cuentas Google pueden usar su propia clave de OpenAI, Claude, Gemini o un servidor compatible. El proveedor establece su cuota y tarifas.

[Configuración](docs/CONFIGURATION.md) · [Desarrollo](docs/PROGRESS.md)

Flutter 3.47.2 · Dart 3.13.2 · Java 17 · Android API 26–36. iOS 15 preparado, sin validar.
