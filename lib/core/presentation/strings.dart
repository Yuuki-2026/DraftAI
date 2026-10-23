import 'package:flutter/material.dart';

String tr(BuildContext context, String es) =>
    Localizations.localeOf(context).languageCode == 'en'
    ? english[es] ?? extraEnglish[es] ?? _dynamicEnglish(es)
    : es;
const english = <String, String>{
  "ACCIONES · APUNTE": "ACTIONS · NOTE",
  "ACCIÓN RÁPIDA": "QUICK ACTION",
  "Exportar como:": "Export as:",
  "Mover a eliminados": "Move to trash",
  "Cambiar el título del apunte": "Change the note title",
  "Encontrar texto clave": "Find key text",
  "Elegir formato de archivo": "Choose a file format",
  "Resumir el apunte completo": "Summarize the whole note",
  "Ver versiones anteriores": "View earlier versions",
  "Toca el fondo para volver al apunte": "Tap outside to return to the note",
  "Documento estándar con imágenes": "Standard document with images",
  "Formato editable": "Editable format",
  "Archivo de texto plano": "Plain text file",
  "Compatible con editores de notas": "Compatible with note editors",
  "Volver a tus apuntes": "Return to your notes",
  "Borrar este apunte y sus archivos": "Delete this note and its files",
  "Los apuntes permanecen aquí hasta que los restaures o elimines definitivamente.":
      "Notes stay here until you restore or permanently delete them.",
  "Buscar carpeta": "Search folders",
  "Buscar apunte": "Search notes",
  "Elige el apunte": "Choose a note",
  "Revisa el destino": "Review destination",
  "Asigna una carpeta para organizar tus apuntes.":
      "Assign a folder to organize your notes.",
  "Elige un apunte existente o crea uno nuevo.":
      "Choose an existing note or create a new one.",
  "Confirma antes de guardar.": "Confirm before saving.",
  "Toca la vista previa para ampliar": "Tap the preview to zoom",
  "Agregar nueva carpeta": "Add a folder",
  "Guardar lote": "Save batch",
  "Confirmar destino": "Confirm destination",
  "Siguiente fuente": "Next source",
  "PASO": "STEP",
  "DE": "OF",
  "Seleccionar": "Select",
  "Actualizado": "Updated",
  "Hace": "ago",
  "días": "days",
  "La fórmula se verá renderizada al guardar el apunte.":
      "The formula will be rendered after saving the note.",
  "Antes de exportar": "Before exporting",
  "Elige un formato. Los originales se conservarán en DraftAI.":
      "Choose a format. Originals will remain in DraftAI.",
  "Texto e imágenes; no incluye PDF ni archivos adjuntos.":
      "Text and images; attached PDFs and other files are not included.",
  "Solo texto; sin imágenes ni archivos adjuntos.":
      "Text only; no images or attached files.",
  "Texto con encabezados; sin imágenes ni archivos adjuntos.":
      "Text with headings; no images or attached files.",
  "No se incluirá el contenido de estos adjuntos:":
      "The contents of these attachments will not be included:",
  "Y otros archivos": "Other files",
  "Las fórmulas se exportan como código LaTeX, sin el renderizado visual de la app.": "Equations are exported as LaTeX source, without the visual rendering shown in the app.",
  "El formato de texto puede simplificarse. Los originales seguirán disponibles en DraftAI.": "Text formatting may be simplified. Originals will remain available in DraftAI.",
  "Dejar en Invitado": "Keep in Guest",
  "Mover apuntes": "Move notes",
  "Beta · En pruebas": "Beta · Testing",
  "¿Guardar los cambios?": "Save changes?",
  "Tienes cambios sin guardar en este apunte.":
      "This note has unsaved changes.",
  "Seguir editando": "Keep editing",
  "Cambios guardados.": "Changes saved.",
  "Icono de la aplicación": "App icon",
  "Elige cómo se ve DraftAI en el lanzador de Android.":
      "Choose how DraftAI looks in the Android launcher.",
  "Original": "Original",
  "Océano": "Ocean",
  "Ámbar": "Amber",
  "Icono actualizado.": "Icon updated.",
  "No se pudo cambiar el icono.": "The icon could not be changed.",
  "El cambio de icono solo está disponible en Android.":
      "Changing the app icon is only available on Android.",
  "Cuestionario": "Quiz",
  "Cuestionario creado localmente a partir del texto del apunte.":
      "Quiz created locally from the note text.",
  "Repasar con preguntas de este apunte":
      "Review with questions from this note",
  "Completa la idea": "Complete the idea",
  "No hay suficiente texto para crear preguntas.":
      "There is not enough text to create questions.",
  "Añade varias frases con conceptos para preparar un repaso.":
      "Add a few concept-rich sentences to prepare a study review.",
  "Respuesta correcta.": "Correct.",
  "Respuesta correcta:": "Correct answer:",
  "Ver resultado": "See results",
  "Siguiente": "Next",
  "Resultado": "Results",
  "Buen repaso. Puedes volver a intentarlo cuando quieras.":
      "Nice review. You can try again whenever you want.",
  "Repasa el apunte y vuelve a intentarlo.": "Review the note and try again.",
  "Intentar de nuevo": "Try again",
  "El apunte podrá restaurarse desde la papelera.":
      "You can restore this note from the trash.",
  "Mostrar indicador de páginas": "Show page indicator",
  "Ocultar indicador de páginas": "Hide page indicator",
  "Salir de lectura": "Exit reading mode",
  "Página": "Page",
  "aprox.": "approx.",
  "Añadir tema": "Add topic",
  "Nombre del tema": "Topic name",
  "Comprobando conexión…": "Checking connection…",
  "Sin conexión verificada a IA": "No verified AI connection",
  "Apuntes y temas": "Notes and topics",
  "Solo se enviarán los apuntes y temas marcados. Las fechas filtran la última edición de cada tema.": "Only checked notes and topics will be sent. Dates filter the latest edit of each topic.",
  "Captura completada": "Capture complete",
  "Añade una fuente para comenzar": "Add a source to get started",
  "¿Qué quieres añadir?": "What would you like to add?",
  "Selecciona imágenes o archivos para organizarlos en tus apuntes.":
      "Choose images or files to organize them in your notes.",
  "Fuentes añadidas": "Sources added",
  "Fuentes listas para organizar": "Sources ready to organize",
  "¿Dónde irán tus fuentes?": "Where should these sources go?",
  "Elegir imágenes": "Choose images",
  "Seleccionar archivos": "Choose files",
  "Vista de lista": "List view",
  "Vista de cuadrícula": "Grid view",
  "Abrir": "Open",
  "Abrir carpeta": "Open folder",
  "más": "more",
  "Cambiar color de carpeta": "Change folder color",
  "Selecciona un color": "Select a color",
  "Sin color": "No color",
  "Sin relleno": "No fill",
  "Estilo de página": "Page style",
  "Liso": "Plain",
  "Renglones": "Ruled",
  "Cuadrícula": "Grid",
  "Puntos": "Dots",
  "Interlineado amplio": "Wide spacing",
  "Color de texto": "Text color",
  "Color de resaltado": "Highlight color",
  "Resaltador": "Highlighter",
  "Quitar color": "Remove color",
  "Amarillo": "Yellow",
  "Verde": "Green",
  "Azul": "Blue",
  "Rosa": "Pink",
  "Naranja": "Orange",
  "Violeta": "Purple",
  "Negro": "Black",
  "Rojo": "Red",
  "Insertar tabla": "Insert table",
  "Celda": "Cell",
  "No se pudo editar la tabla.": "The table could not be edited.",
  "Personalización": "Personalization",
  "Nombre dentro de la aplicación": "In-app name",
  "Este nombre aparece en los encabezados y en el título de la ventana.":
      "This name appears in app headers and the window title.",
  "Guardar nombre": "Save name",
  "Nombre actualizado.": "Name updated.",
  "Invitado": "Guest",
  "Un buen nombre ayuda a clasificar mejor a la IA.":
      "A good title helps AI classify it more accurately.",
  "Escribe un título para guardar el apunte.":
      "Enter a title to save this note.",
  "Asigna cada fuente a una carpeta y a un apunte.":
      "Assign each source to a folder and a note.",
  "Déjalo a la IA": "Let AI handle it",
  "Hazlo tú": "Do it yourself",
  "Lectura, resumen interno y destino sugerido por fuente":
      "Read, summarize and suggest a destination for each source",
  "Elige carpeta y apunte para cada archivo":
      "Choose a folder and note for each file",
  "Déjalo a la IA · Analizando": "AI · Analyzing",
  "PASO 1 DE 2 · ANALIZANDO": "STEP 1 OF 2 · ANALYZING",
  "Leyendo contenido y buscando destinos por nombre":
      "Reading sources and matching destination names",
  "Analizando y organizando…": "Analyzing and organizing…",
  "No se completó el análisis": "Analysis did not finish",
  "Extrayendo texto y fórmulas": "Extracting text and formulas",
  "Identificando contenido académico": "Identifying academic material",
  "Sugiriendo carpeta y apunte": "Suggesting a folder and note",
  "En curso": "In progress",
  "Detenido": "Stopped",
  "Cancelar proceso": "Cancel process",
  "Volver al lote": "Back to batch",
  "Revisar las fuentes analizadas": "Review analyzed sources",
  "Editar destino": "Edit destination",
  "Crear una carpeta nueva": "Create a new folder",
  "Apunte de destino": "Destination note",
  "Crear un apunte nuevo": "Create a new note",
  "Texto leído · revisa y corrige": "Extracted text · review and correct",
  "Resumen interno · al final del apunte":
      "Internal summary · at the end of the note",
  "Guardar y continuar": "Save and continue",
  "DESTINO MANUAL": "MANUAL DESTINATION",
  "DESTINO SUGERIDO": "SUGGESTED DESTINATION",
  "Contenido académico": "Academic material",
  "No parece material académico · revisión manual":
      "Possibly nonacademic · manual review",
  "Analizado por IA": "Analyzed by AI",
  "Texto y resumen": "Text and summary",
  "Hazlo tú · Categorizar": "Manual organization",
  "Análisis de fuentes": "Source analysis",
  "PASO 2 / 2 · REVISIÓN Y CONFIRMACIÓN": "STEP 2 / 2 · REVIEW AND CONFIRM",
  "Auto-organización": "Auto organization",
  "Manual": "Manual",
  "fuentes en el lote": "sources in the batch",
  "fuentes analizadas": "sources analyzed",
  "Elige el destino de cada fuente": "Choose a destination for each source",
  "Lectura y análisis de contenido": "Reading and content analysis",
  "¿Dónde va este apunte?": "Where does this note belong?",
  "Resultados de clasificación": "Organization results",
  "Aplicar este destino a todo el lote": "Apply this destination to the batch",
  "Revisión de lote": "Batch review",
  "El proceso terminó": "Analysis finished",
  "Continuar y organizar lote": "Continue and organize batch",
  "Resumen generado por IA": "AI generated summary",
  "Texto mejorado por IA": "Text improved by AI",
  "Modelo no registrado en esta versión anterior":
      "Model not recorded in this older version",
  "El modelo no propuso cambios para esta selección.":
      "The model did not suggest changes for this selection.",
  "Mantener": "Keep",
  "Generado por IA": "Generated by AI",
  "Añadir resumen al final": "Add summary at the end",
  "Despliega o contrae la lista para revisar los apuntes":
      "Expand or collapse the list to review notes",
  "Contexto preparado sin consultar un modelo":
      "Context prepared without calling an AI model",
  "Un nombre claro ayuda a la IA a elegir este apunte.":
      "A clear title helps AI choose this note.",
  "No parece material académico": "Possibly nonacademic",
  "fuentes": "sources",
  "Revisa cada carpeta y apunte antes de guardar. Un título claro ayuda a clasificar futuras fuentes.": "Review every folder and note before saving. Clear titles help classify future sources.",
  "Usa nombres claros de materia y apunte: ayudan a la IA a elegir el destino correcto.": "Use clear subject and note names so AI can choose the right destination.",
  "Solo se guardarán las fuentes seleccionadas. Los resúmenes aparecerán al final del apunte, identificados con su modelo.": "Only selected sources will be saved. Summaries appear at the end of the note, labeled with their model.",
  'Modo lectura': 'Reading mode',
  'Lectura activa': 'Reading active',
  'Reducir texto': 'Decrease text size',
  'Ampliar texto': 'Increase text size',
  'Tipos': 'Styles',
  'Tipos y formato': 'Styles and formatting',
  'Fórmula': 'Formula',
  'Insertar': 'Insert',
  'Color de carpeta': 'Folder color',
  'Renombrar carpeta': 'Rename folder',
  'Guardado en': 'Saved in',

  'Volver': 'Back',
  'Guardar': 'Save',
  'Cancelar': 'Cancel',
  'Cerrar': 'Close',
  'Editar apunte': 'Edit note',
  'Vista del apunte': 'Note',
  'Título de la sesión': 'Title',
  'Tema': 'Topic',
  'Escribe tus ideas aquí…': 'Write your ideas here…',
  'Nuevo': 'New',
  'Editar': 'Edit',
  'Lectura': 'Read',
  'Exportar': 'Export',
  'Más': 'More',
  'Dictar': 'Dictate',
  'Detener': 'Stop',
  'Cámara': 'Camera',
  'Mejorar': 'Improve',
  'Archivos': 'Files',
  'Añadir imágenes': 'Add images',
  'Añadir contenido al apunte': 'Add content to the note',
  'Elegir imágenes de la galería': 'Choose images from the gallery',
  'Tomar una fotografía para el apunte': 'Take a photo for the note',
  'Adjuntar un PDF u otro archivo': 'Attach a PDF or another file',
  'Sin categoría': 'No category',
  '+ Categoría': '+ Category',
  'Historial de versiones': 'Version history',
  'Resumen interno': 'Summary',
  'Herramientas de IA': 'AI tools',
  'Generar resumen': 'Summarize',
  'Enviar contexto': 'Export context',
  'IA externa': 'External AI',
  'Aplicar': 'Apply',
  'Aceptar': 'Accept',
  'Revertir': 'Revert',
  'Texto mejorado': 'Improved text',
  'Selecciona el texto que quieres mejorar.':
      'Select the text you want to improve.',
  'Revisar cambio de IA': 'Review AI edit',
  'Contenido modificado. Vuelve a seleccionar el texto.':
      'Content changed. Select the text again.',
  'Inicia sesión con Google para consultar tu cuota de IA.':
      'Sign in with Google to view your AI quota.',
  'El límite se reinicia a medianoche, hora de Lima. Cada operación correcta cuenta como un uso.': 'The limit resets at midnight Lima time. Each successful operation counts as one use.',
  'El servidor de IA no tiene habilitado el análisis de imágenes.':
      'Image analysis is not enabled on the AI server.',
  'Funciones': 'Features',
  'Sí': 'Yes',
  'Pro demo': 'Pro demo',
  'Acceso Pro autorizado': 'Authorized Pro access',
  'nombre-del-modelo': 'model-name',
  'Conectar': 'Connect',
  'Desconectar': 'Disconnect',
  'IA conectada': 'AI connected',
  'Servidor de prueba': 'Test server',
  'Sin conexión a IA': 'AI not connected',
  'PDF adjunto': 'Attached PDF',
  'Documento adjunto': 'Attached document',
  'No se pudo abrir el archivo.': 'Unable to open the file.',
  'Quitar adjunto': 'Remove attachment',
  'No se pudo abrir la imagen.': 'Unable to open the image.',
  '¿Dónde irán tus fotos?': 'Where should your photos go?',
  'Nota de destino': 'Destination note',
  'Crear una nota nueva': 'Create one new note',
  'Continuar en el editor': 'Continue in editor',
  'Añadir otra': 'Add more',
  'Descartar lote': 'Discard batch',
  'Imágenes': 'Images',
  'Analizar imágenes': 'Read images',
  'Selecciona al menos un archivo.': 'Select at least one file.',
  'Revisa el resultado antes de guardarlo.': 'Review the result before saving.',
  'Inicio': 'Home',
  'Apuntes': 'Notes',
  'Papelera': 'Trash',
  '+ Nuevo': '+ New',
  'Recientes': 'Recent',
  'Ver todos': 'View all',
  'Nueva nota': 'New note',
  'Tus carpetas': 'Your folders',
  'Nueva carpeta': 'New folder',
  'Agregar apunte': 'Add note',
  'Preferencias': 'Preferences',
  'Idioma': 'Language',
  'Tema visual': 'Theme',
  'Oscuro puro': 'Dark',
  'Claro': 'Light',
  'Automático': 'System',
  'Sin título': 'Untitled',
  'Mis apuntes': 'My notes',
};

const extraEnglish = <String, String>{
  'Resaltar texto': 'Highlight text',
  'Generado con IA': 'Generated with AI',
  'La IA está preparando el cuestionario…': 'AI is preparing your quiz…',
  'El apunte debe tener texto y no superar 12000 caracteres.':
      'The note must contain text and be under 12,000 characters.',
  'Añade texto al apunte para crear un cuestionario.':
      'Add text to the note to generate a quiz.',
  'La IA no encontró material para crear preguntas.':
      'The AI could not find enough material to create questions.',
  'Editar perfil': 'Edit profile',
  'Cambiar foto': 'Change photo',
  'Quitar foto': 'Remove photo',
  'Nombre': 'Name',
  'Elige el fondo de tus apuntes.':
      'Choose the page background for your notes.',
  'Crear un apunte en una carpeta': 'Create a note in a folder',
  'Usar la cámara del dispositivo': 'Use the device camera',
  'Elegir fotos de la galería': 'Choose photos from gallery',
  'Importar documentos compatibles': 'Import supported documents',
  'Conectar IA': 'Connect AI',
  'IA de Invitado': 'Guest AI',
  'Proveedor configurado. La cuota y disponibilidad dependen de ese proveedor.': 'Provider configured. Availability and usage limits depend on that provider.',
  'Conecta un proveedor compatible desde Herramientas de IA.':
      'Connect a compatible provider from AI tools.',
  'Usa un proveedor compatible con OpenAI Chat Completions. La disponibilidad y los límites dependen del proveedor que elijas.': 'Use a provider compatible with OpenAI Chat Completions. Availability and limits depend on your provider.',
  'URL base HTTPS': 'HTTPS base URL',
  'Modelo': 'Model',
  'Clave API del proveedor': 'Provider API key',
  'Déjala vacía para conservar la clave guardada en este teléfono.':
      'Leave blank to keep the key saved on this phone.',
  'La clave se guarda de forma segura en este teléfono.':
      'The key is stored securely on this phone.',
  'El texto o las imágenes que proceses se enviarán al proveedor configurado.':
      'Text or images you process will be sent to the configured provider.',
  'Guardar conexión': 'Save connection',
  'Proveedor configurado': 'Provider configured',
  'Cuota y disponibilidad según tu proveedor.':
      'Usage limits and availability depend on your provider.',
  'Configura URL, modelo y clave API para este dispositivo.':
      'Set the URL, model, and API key for this device.',
  'IA de DraftAI': 'DraftAI AI',
  'IA en la nube no disponible': 'Cloud AI unavailable',
  'La conexión de Azure se habilitará cuando el servicio esté configurado.':
      'Azure connectivity will be enabled when the service is configured.',
  'La IA de tu cuenta de Google se habilitará al conectar el servicio de DraftAI.': 'AI for your Google account will be enabled when the DraftAI service is connected.',
  'La conexión de IA en la nube aún no está configurada.':
      'Cloud AI is not configured yet.',
  'La IA de tu cuenta todavía no está disponible. El backend de Azure debe estar configurado.': 'AI for your account is not available yet. The Azure backend must be configured.',
  'Las cuentas de Google usan el servicio de IA de DraftAI; no configuran una clave propia.':
      'Google accounts use DraftAI AI and cannot configure their own key.',
  'Este proveedor procesa imágenes y texto, pero no archivos PDF. Extrae o exporta el texto del documento y vuelve a intentarlo.': 'This provider processes images and text, but not PDF files. Extract or export the document text and try again.',
  'Este tipo de archivo no es compatible con el proveedor elegido.':
      'This file type is not supported by the selected provider.',
  'El proveedor alcanzó su límite o cuota. Revisa tu cuenta e inténtalo más tarde.': 'The provider reached its limit or quota. Check your account and try again later.',
  'El proveedor rechazó la clave. Revísala en la configuración de IA de Invitado.':
      'The provider rejected the key. Check it in Guest AI settings.',
  'El proveedor no encontró el modelo o la dirección configurada.':
      'The provider could not find the model or configured URL.',
  'El proveedor no pudo completar la solicitud. Inténtalo de nuevo.':
      'The provider could not complete the request. Try again.',
  'Reduce el tamaño de las fuentes. El proveedor Invitado admite hasta 15 MB por solicitud.': 'Reduce the source size. The Guest provider supports up to 15 MB per request.',
  'El tipo de archivo no es compatible con este proveedor.':
      'This provider does not support this file type.',
  'Introduce la URL base HTTPS del proveedor, sin clave ni parámetros.':
      'Enter the provider HTTPS base URL without a key or query parameters.',
  'Introduce la clave API de tu proveedor.': 'Enter your provider API key.',
  'La clave API no tiene un formato válido.': 'The API key format is invalid.',
  'Introduce el identificador del modelo.': 'Enter the model identifier.',
  'No se pudo conectar con el proveedor o su respuesta no es válida.':
      'Unable to connect to the provider or its response is invalid.',
  'El proveedor tardó demasiado en responder. Inténtalo de nuevo.':
      'The provider took too long to respond. Try again.',
  'Pregunta': 'Question',
  'Reintentar': 'Try again',
  'Se enviará el texto del apunte al servicio de IA para preparar preguntas. ¿Continuar?': 'The note text will be sent to the AI service to prepare questions. Continue?',
  'Biblioteca de prueba': 'Sample library',
  'Cargar o eliminar ejemplos': 'Load or remove sample notes',
  'Cargar ejemplos': 'Load samples',
  'Eliminar ejemplos': 'Remove samples',
  'ejemplos cargados': 'samples loaded',
  'ejemplos eliminados': 'samples removed',
  'Se eliminarán solo las notas de ejemplo, incluidos los cambios que les hayas hecho. Tus notas propias se conservan.': 'Only sample notes, including your changes to them, will be removed. Your own notes are preserved.',
  'Carga 120 notas ficticias en 8 carpetas, 24 temas y fechas de los últimos ocho meses, con imágenes, PDF y textos para probar edición, lectura, IA y exportación. La instalación inicial permanece vacía hasta que lo solicites.': 'Load 120 fictional notes in 8 folders, with 24 topics and dates across eight months, including images, PDF and text to try editing, reading, AI and export. New installations remain empty until you request samples.',
  'Categoría': 'Category',
  'el inicio': 'the beginning',
  'hoy': 'today',

  "Acciones IA al día": "Daily AI actions",
  "Acciones de IA": "AI actions",
  "Acciones de mantenimiento": "Maintenance",
  "Acciones del apunte": "Note actions",
  "Acerca de DraftAI": "About DraftAI",
  "Activar vista previa de Pro": "Enable Pro preview",
  "Agregar archivos o texto": "Add files or text",
  "Almacenamiento": "Storage",
  "Almacenamiento local": "Local storage",
  "Almacén cifrado": "Encrypted storage",
  "Android primero": "Android first",
  "Aplicar cambios y guardar": "Apply and save",
  "Apuntes e imágenes": "Notes and images",
  "Apuntes recientes": "Recent notes",
  "Archivo adjunto": "Attachment",
  "Archivos adjuntos cifrados": "Encrypted attachments",
  "Ayuda y acerca de": "Help and about",
  "Añadir a tus apuntes": "Add to your notes",
  "Añadir apunte": "Add note",
  "Añadir imágenes y PDF": "Add images and PDF",
  "Añadir instrucción": "Add instruction",
  "Aún no hay apuntes en esta carpeta.": "This folder has no notes yet.",
  "Buscar": "Search",
  "Buscar apuntes": "Search notes",
  "Buscar en tus apuntes": "Search your notes",
  "Buscar por voz": "Voice search",
  "Búsqueda por voz": "Voice search",
  "Cambios sin guardar": "Unsaved changes",
  "Capacidad local": "Local storage",
  "Capturar fotografías": "Take photos",
  "Cargar ejemplos del mockup": "Load sample library",
  "Carpeta existente o nueva": "Existing or new folder",
  "Categoría (opcional)": "Category (optional)",
  "Categoría existente o nueva": "Existing or new category",
  "Centro de ayuda": "Help center",
  "Colores recomendados": "Suggested colors",
  "Comparativa de planes": "Compare plans",
  "Conservación": "Keeping your notes",
  "Contexto para IA externa": "Context for external AI",
  "Continuar sin cuenta": "Continue as guest",
  "Copiado al portapapeles.": "Copied to clipboard.",
  "Crea tu primer apunte o añade imágenes.":
      "Create your first note or add images.",
  "Crear": "Create",
  "Crear apunte": "Create note",
  "Crear categoría": "Create category",
  "Crear tu primera nota": "Create your first note",
  "Datos en este dispositivo": "Guest library",
  "Datos locales": "Local data",
  "Demostración · limpieza de texto": "Demo: text cleanup",
  "Descartar": "Discard",
  "Deshacer": "Undo",
  "Rehacer": "Redo",
  "Detener voz": "Stop voice input",
  "Edición": "Edit",
  "Editar carpeta": "Edit folder",
  "Ej. Cálculo diferencial": "e.g. Differential calculus",
  "Ej. Exámenes": "e.g. Exams",
  "Ej. Geometría diferencial": "e.g. Differential geometry",
  "El archivo compartido podrá leerse fuera de DraftAI.":
      "Shared files can be read outside DraftAI.",
  "El dictado no está disponible. Revisa el permiso de micrófono.":
      "Dictation is unavailable. Check microphone permission.",
  "El lote admite hasta 20 archivos.": "A batch supports up to 20 files.",
  "Elige dónde guardar este apunte.": "Choose where to save this note.",
  "Eliminar": "Delete",
  "Eliminar carpeta": "Delete folder",
  "Eliminar definitivamente": "Delete permanently",
  "Enviar a la papelera": "Move to trash",
  "Enviar a papelera": "Move to trash",
  "Enviar a una IA externa": "Send to external AI",
  "Escribe el título y la carpeta.": "Enter a title and folder.",
  "Escribir nota": "Write note",
  "Escuchando… Puedes detener el micrófono cuando termines.":
      "Listening… Stop the microphone when finished.",
  "Exportación y eliminación": "Export and deletion",
  "Exportar PDF, Word, texto": "Export PDF, Word, text",
  "Exportar como": "Export as",
  "Exportar copia local": "Export backup",
  "Gratis": "Free",
  "Guías, privacidad y licencias": "Guides, privacy and licenses",
  "Hasta 10 acciones de IA al día": "Up to 10 AI actions per day",
  "Historial y revertir cambios": "History and undo changes",
  "IA y contexto externo": "AI and external context",
  "Información": "Information",
  "Iniciar sesión con Google": "Sign in with Google",
  "Insertar en apunte": "Insert into note",
  "La fecha inicial debe ser anterior a la fecha final.":
      "The start date must be before the end date.",
  "La versión actual quedará guardada en el historial.":
      "The current version will remain in history.",
  "Limpiar": "Clear",
  "Limpiar caché de exportaciones": "Clear export cache",
  "Listado de temas": "Topics",
  "Los apuntes eliminados aparecerán aquí.": "Deleted notes will appear here.",
  "Los ejemplos solo se cargan en una biblioteca vacía.":
      "Samples can only be loaded into an empty library.",
  "MOTOR CONTEXTUAL": "NOTE TOOLS",
  "Mantén pulsado un apunte para seleccionar varios.":
      "Long press a note to select several.",
  "Markdown · archivo .md": "Markdown file",
  "Modo demostrativo: se extraen frases del texto local. No se consulta un modelo de IA.":
      "Demo mode extracts sentences locally. No AI model is called.",
  "Modo invitado": "Guest mode",
  "Mueve o elimina los apuntes de esta carpeta primero.":
      "Move or delete the notes in this folder first.",
  "No se encontraron apuntes. Prueba otra palabra.":
      "No notes found. Try another word.",
  "No se pudo guardar. Toca Guardar para reintentar.":
      "Unable to save. Tap Save to retry.",
  "Nombre de carpeta": "Folder name",
  "Nombre de categoría": "Category name",
  "Nombre de la carpeta": "Folder name",
  "Notas e imágenes del dispositivo": "Notes and images",
  "Nueva categoría": "New category",
  "OCR remoto": "Image reading",
  "PDF · documento con imágenes": "PDF with images",
  "PLAN ACTUAL": "CURRENT PLAN",
  "PLAN PRO": "PRO PLAN",
  "Perfil": "Profile",
  "Política de privacidad": "Privacy policy",
  "Precio ilustrativo · sin facturación": "Example price, no billing",
  "Preparando copia…": "Preparing backup…",
  "Preparar contexto": "Prepare context",
  "Previsualización": "Preview",
  "Pro · demostración": "Pro preview",
  "Procesar con IA": "Process with AI",
  "Prompt estructurado": "Structured prompt",
  "Propuesta de organización": "Suggested organization",
  "Quitar adjunto": "Remove attachment",
  "Recuperar y exportar": "Recover and export",
  "Reemplazar texto": "Replace text",
  "Renombrar o mover": "Rename or move",
  "Restauración de historial": "History restore",
  "Restaurar": "Restore",
  "Restaurar original": "Reset original",
  "Restaurar versión": "Restore version",
  "Resumen generado": "Generated summary",
  "Resúmenes y contexto para otras herramientas":
      "Summaries and context for other tools",
  "Resúmenes y mejoras comparten el límite diario. El contador se renueva cada día.":
      "Summaries and improvements share the daily limit. It resets each day.",
  "Revisar cambios": "Review changes",
  "Revisar clasificación": "Review classification",
  "Revisión del contenido": "Content review",
  "Salir": "Sign out",
  "Se eliminará este apunte y sus archivos. Esta acción no se puede deshacer.": "This note and its files will be permanently deleted. This cannot be undone.",
  "Se enviará únicamente el texto seleccionado al servicio de IA. ¿Continuar?":
      "Only the selected text will be sent to the AI service. Continue?",
  "Se enviarán las imágenes al proveedor para transcribir su contenido. Revisarás la propuesta antes de guardar.": "Images will be sent to the provider for transcription. You can review the result before saving.",
  "Selecciona al menos un apunte con texto.":
      "Select at least one note containing text.",
  "Selecciona hasta 5 imágenes para su lectura.":
      "Select up to 5 images to read.",
  "Seleccionar fechas": "Select dates",
  "Seleccionar temas": "Select topics",
  "Servicios externos": "External services",
  "Sin apuntes todavía": "No notes yet",
  "Sin cobros ni compra real": "No charges or real purchases",
  "Sin contenido todavía": "No content yet",
  "Suscripción": "Subscription",
  "TUS IDEAS, SIEMPRE A MANO": "YOUR IDEAS, ALWAYS WITH YOU",
  "También se eliminarán sus categorías. Esta acción no se puede deshacer.":
      "Its categories will also be deleted. This cannot be undone.",
  "Tema y ajustes locales": "Theme and preferences",
  "Texto extraído · revisa su exactitud":
      "Transcribed text: review its accuracy",
  "Texto · archivo .txt": "Plain text file",
  "Toca un apunte para seleccionarlo o mantenerlo pulsado para empezar.":
      "Tap a note to select it, or long press to start.",
  "Toca una línea del texto y luego pulsa Insertar.":
      "Tap a line in the text, then tap Insert.",
  "Todavía no hay versiones anteriores.": "There are no earlier versions yet.",
  "Tono": "Hue",
  "Tu papelera está vacía": "Your trash is empty",
  "Tus apuntes": "Your notes",
  "Tus apuntes, imágenes y aprendizajes organizados en un solo espacio.":
      "Your notes, images and learning in one place.",
  "Tus ideas empiezan aquí": "Your ideas start here",
  "Términos de uso": "Terms of use",
  "Título": "Title",
  "Título del apunte": "Note title",
  "Usa + Nuevo para comenzar.": "Use + New to get started.",
  "Uso de DraftAI": "Using DraftAI",
  "Vaciar": "Empty",
  "Vaciar papelera": "Empty trash",
  "Ventana temporal": "Date range",
  "Ver Plan Pro": "View Pro plan",
  "Versiones anteriores": "Previous versions",
  "Vista previa": "Preview",
  "Vista previa de Pro activada. No se ha realizado ningún cobro.":
      "Pro preview enabled. No payment was made.",
  "Volver a Gratis": "Return to Free",
  "Volviste a Gratis. Tus apuntes se conservan.":
      "You returned to Free. Your notes are preserved.",
  "Voz y permisos": "Voice and permissions",
  "Word · documento editable": "Editable Word document",
  "Últimos 7 días": "Last 7 days",
  "Desde": "From",
  "Hasta": "To",
  "Todo": "All",
  "Confirmar": "Confirm",
  "ORIGINAL": "ORIGINAL",
  "PROPUESTA": "PROPOSAL",
  "Copiar": "Copy",
  "Copiar al portapapeles": "Copy to clipboard",
  "Sin tema": "No topic",
  "Genera un mapa mental en Markdown y Mermaid.":
      "Generate a mind map in Markdown and Mermaid.",
  "Genera una infografía con jerarquía y secciones.":
      "Generate an infographic with hierarchy and sections.",
  "Genera un gráfico y explica los datos disponibles.":
      "Generate a chart and explain the available data.",
  "Genera apuntes ilustrados con descripciones de imágenes.":
      "Generate illustrated notes with image descriptions.",
  'No volver a mostrar; puedes moverlos desde Preferencias.':
      'Do not show again; you can move them from Preferences.',
  'Cambiar foto de perfil': 'Change profile photo',
  'Editar nombre': 'Edit name',
  'Ajustar foto de perfil': 'Adjust profile photo',
  'Alinear a la izquierda': 'Align left',
  'Alinear a la derecha': 'Align right',
  'Centrar imagen': 'Center image',
  'Arrastra la imagen o usa dos dedos para ajustar el encuadre.':
      'Drag the image or use two fingers to adjust the crop.',
  'Usar foto': 'Use photo',
  'No se pudo guardar el recorte.': 'Could not save the crop.',
  'Fuente de la aplicación': 'App font',
  'Clásica': 'Serif',
  'Monoespaciada': 'Monospace',
  'Traslado de apuntes': 'Note transfer',
  'Recordarme mover apuntes de Invitado': 'Remind me to move Guest notes',
  'Puedes cambiar esta opción cuando quieras.':
      'You can change this setting at any time.',
  'Importar apuntes de Invitado': 'Import Guest notes',
  'apuntes disponibles': 'notes available',
  'Se moverán a la bóveda cifrada de esta cuenta en este teléfono. DraftAI verificará la copia antes de retirarlos de Invitado. Aún no hay sincronización en la nube.': 'They will move to this account’s encrypted vault on this phone. DraftAI verifies the copy before removing them from Guest. Cloud sync is not available yet.',
  'Vista previa de PDF': 'PDF preview',
  'Filas': 'Rows',
  'Columnas': 'Columns',
  'Vista previa de Word': 'Word preview',
  'Vista previa del documento': 'Document preview',
  'Exportar apuntes seleccionados': 'Export selected notes',
  'Un documento': 'One document',
  'Un archivo por apunte': 'One file per note',
  'Personalizar documento': 'Customize document',
  'Tamaño de las imágenes': 'Image size',
  'Tamaño de títulos': 'Title size',
  'Márgenes de página': 'Page margins',
  'Texto del pie de página': 'Footer text',
  'Incluir fecha': 'Include date',
  'Mostrar número de página': 'Show page number',
  'Las imágenes no se incrustan en este formato; se marcará su posición con el nombre del archivo.': 'Images are not embedded in this format; their position will be marked with the file name.',
  'Añadir': 'Add',
  'Bienvenido': 'Welcome',
  'Captura': 'Capture',
  'Cargar biblioteca de ejemplo': 'Load sample library',
  'Carpeta': 'Folder',
  'Conecta la IA para resumir tus apuntes. No se generará un resultado simulado.': 'Connect an AI service to summarize your notes. No simulated result will be generated.',
  'Desinstalar la app elimina sus datos y su clave. Exporta antes los apuntes que quieras conservar.': 'Uninstalling the app deletes its data and key. Export any notes you want to keep first.',
  'Escribe la carpeta y el título del apunte.':
      'Enter the folder and note title.',
  'Explora las herramientas inteligentes. Los planes son demostrativos: no se realizan cobros.':
      'Explore the smart tools. Plans are demonstrations; no charges are made.',
  'Extracción parcial: revisa el original antes de guardar.':
      'Partial extraction: review the original before saving.',
  'Guardado': 'Saved',
  'Guardar en': 'Save to',
  'Hasta 20 fuentes por lote. La IA procesa grupos de hasta 5 y 10 MB; PDF de hasta 12 páginas, TXT/MD y fotos.': 'Up to 20 sources per batch. AI processes groups of up to 5 files and 10 MB; PDFs up to 12 pages, TXT/MD files, and photos.',
  'La IA lee las fuentes, prepara un resumen interno y sugiere carpeta y apunte.': 'AI reads the sources, prepares an internal summary, and suggests a folder and note.',
  'La IA necesita conexión. Gratis usa Groq; Pro autorizado usa GPT-5 nano para texto, imágenes, PDF y TXT/MD. Cada resultado indica el modelo utilizado. Los planes no procesan pagos.': 'AI requires an internet connection. Free uses Groq; authorized Pro uses GPT-5 nano for text, images, PDF, and TXT/MD. Each result shows the model used. Plans do not process payments.',
  'Licencias': 'Licenses',
  'Mueve los apuntes o elimínalos definitivamente de la papelera antes de borrar la carpeta.': 'Move the notes or permanently delete them from the trash before deleting the folder.',
  'No se pudo consultar la cuota. Actualiza para reintentar.':
      'Could not check the quota. Refresh to try again.',
  'No se pudo leer con claridad. Puedes adjuntarlo manualmente.':
      'The content could not be read clearly. You can attach it manually.',
  'Nuevo apunte': 'New note',
  'Privacidad': 'Privacy',
  'Propuesta': 'Suggestion',
  'Selecciona al menos una fuente.': 'Select at least one source.',
  'Sin resultados': 'No results',
  'Solo se muestran resultados cuando el proveedor responde. No se guarda nada sin tu revisión.': 'Results appear only when the provider responds. Nothing is saved without your review.',
  'Todos / ninguno': 'All / none',
  'Tus apuntes e imágenes permanecen cifrados en el almacenamiento privado de la app. La clave se protege con Keystore/Keychain. No existe sincronización entre dispositivos.': 'Your notes and images stay encrypted in the app’s private storage. The key is protected by Keystore/Keychain. There is no device-to-device sync.',
  'Usos de IA': 'AI usage',
  'Exportar texto': 'Export text',
  'Copiar contenido': 'Copy content',
  'Copiar el texto para pegarlo en otra aplicación':
      'Copy text to paste into another app',
  'Compartir archivo': 'Share file',
  'Crear un archivo .txt o .md': 'Create a .txt or .md file',
  'Apunte anterior': 'Previous note',
  'Siguiente apunte': 'Next note',
  'Mantén pulsado y arrastra para mover': 'Press and hold, then drag to move',
  'Seleccionar apunte': 'Select note',
  'Texto copiado al portapapeles.': 'Text copied to clipboard.',
  'Abrir perfil': 'Open profile',
  'Actualizar': 'Refresh',
  'apuntes': 'notes',
  'elementos': 'items',
  'seleccionados': 'selected',
  'Alcanzaste el límite diario de IA. Podrás volver a usarla mañana.':
      'You reached the daily AI limit. You can use it again tomorrow.',
  'Alcanzaste el límite diario de IA. Vuelve a intentarlo mañana.':
      'You reached the daily AI limit. Try again tomorrow.',
  'Archivo vacío o mayor de 15 MB.': 'The file is empty or larger than 15 MB.',
  'Cada archivo debe pesar menos de 15 MB.':
      'Each file must be smaller than 15 MB.',
  'Cada fuente para IA debe pesar hasta 8 MB.':
      'Each AI source must be no larger than 8 MB.',
  'Cada imagen debe pesar menos de 15 MB.':
      'Each image must be smaller than 15 MB.',
  'Conecta la IA para generar un cuestionario.':
      'Connect an AI service to generate a quiz.',
  'Divide el lote: admite hasta 60 MB en total.':
      'Split the batch. The total limit is 60 MB.',
  'El OCR está disponible en la vista previa de Pro. En Gratis puedes adjuntar imágenes sin procesarlas.': 'OCR is available in the Pro preview. On Free, you can attach images without processing them.',
  'El PDF está dañado, protegido o no es compatible.':
      'The PDF is damaged, protected, or unsupported.',
  'El apunte no contiene texto para procesar.':
      'The note has no text to process.',
  'El archivo supera 15 MB.': 'The file is larger than 15 MB.',
  'El contenido de un apunte no se pudo trasladar. Tus datos de Invitado siguen intactos.':
      'A note could not be transferred. Your Guest data is still intact.',
  'El contenido del archivo no coincide con su formato o supera los límites permitidos.': 'The file content does not match its format or exceeds the allowed limits.',
  'El historial de destino no coincide. Los apuntes de Invitado siguen intactos.': 'The destination history does not match. Your Guest notes are still intact.',
  'El lote admite hasta 20 fuentes.': 'A batch can contain up to 20 sources.',
  'El proveedor devolvió un resultado no válido.':
      'The provider returned an invalid result.',
  'El servicio de IA alcanzó su límite diario. Vuelve a intentarlo mañana.':
      'The AI service reached its daily limit. Try again tomorrow.',
  'El servicio de IA debe usar HTTPS.': 'The AI service must use HTTPS.',
  'El título debe tener entre 1 y 200 caracteres.':
      'The title must contain 1 to 200 characters.',
  'Escribe una categoría de hasta 80 caracteres.':
      'Enter a category name up to 80 characters long.',
  'Espera a que termine la operación actual.':
      'Wait for the current operation to finish.',
  'Falta la clave de los datos existentes. No se reemplazará ni borrará tu biblioteca.': 'The key for existing data is missing. Your library will not be replaced or deleted.',
  'Falta un resultado por fuente.':
      'A result is missing for one of the sources.',
  'Faltan resultados de algunas fuentes.': 'Some sources are missing results.',
  'Formato de apunte no compatible.': 'Unsupported note format.',
  'Google no devolvió un token de acceso válido.':
      'Google did not return a valid access token.',
  'Google no devolvió una cuenta válida.':
      'Google did not return a valid account.',
  'Identificador de archivo no válido.': 'Invalid file identifier.',
  'Imagen demasiado grande.': 'The image is too large.',
  'Inicia sesión con Google para usar el servicio de IA.':
      'Sign in with Google to use the AI service.',
  'La IA devolvió opciones repetidas.': 'The AI returned duplicate options.',
  'La IA devolvió un cuestionario incompleto.':
      'The AI returned an incomplete quiz.',
  'La IA devolvió un texto vacío.': 'The AI returned empty text.',
  'La IA devolvió una pregunta no válida.':
      'The AI returned an invalid question.',
  'La IA devolvió una respuesta estructurada no válida.':
      'The AI returned an invalid structured response.',
  'La carpeta debe tener entre 1 y 80 caracteres.':
      'The folder name must contain 1 to 80 characters.',
  'La categoría no pertenece a esta carpeta.':
      'This category does not belong to the selected folder.',
  'La conexión de IA de Google se administra desde DraftAI.':
      'Google AI access is managed by DraftAI.',
  'La imagen está dañada o excede el tamaño permitido.':
      'The image is damaged or exceeds the allowed size.',
  'Los ejemplos ya están cargados.': 'The sample notes are already loaded.',
  'Mueve o elimina definitivamente los apuntes de esta carpeta primero.':
      'Move or permanently delete this folder’s notes first.',
  'No se pudo abrir el almacén seguro. Desbloquea el dispositivo y vuelve a intentar.':
      'Could not open secure storage. Unlock the device and try again.',
  'No se pudo abrir la cámara o los archivos. Revisa los permisos del dispositivo.':
      'Could not open the camera or files. Check device permissions.',
  'No se pudo conectar con la IA o su respuesta no es válida.':
      'Could not connect to AI, or its response was invalid.',
  'No se pudo identificar esta cuenta de Google.':
      'Could not identify this Google account.',
  'No se pudo identificar la cuenta de destino.':
      'Could not identify the destination account.',
  'No se pudo iniciar Firebase. Revisa la configuración de Android y vuelve a intentarlo.': 'Could not start Firebase. Check the Android configuration and try again.',
  'No se pudo iniciar sesión con Google. Revisa la cuenta y la conexión, e inténtalo de nuevo.': 'Could not sign in with Google. Check the account and connection, then try again.',
  'No se pudo leer el archivo adjunto.': 'Could not read the attachment.',
  'No se pudo preparar una imagen para Word.':
      'Could not prepare an image for Word.',
  'No se pudo proteger la clave de los apuntes.':
      'Could not protect the notes key.',
  'No se pudo retirar la clave de los apuntes.':
      'Could not remove the notes key.',
  'No se pudo verificar el contenido de un apunte. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.':
      'Could not verify a note. Your Guest notes are still intact; try again.',
  'No se pudo verificar el contenido del historial. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.': 'Could not verify the note history. Your Guest notes are still intact; try again.',
  'No se pudo verificar el historial de un apunte. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.': 'Could not verify a note history. Your Guest notes are still intact; try again.',
  'No se pudo verificar la integridad del contenido cifrado.':
      'Could not verify the integrity of the encrypted content.',
  'No se pudo verificar todo el traslado. Tus apuntes de Invitado siguen intactos; vuelve a intentarlo.': 'Could not verify the full transfer. Your Guest notes are still intact; try again.',
  'No se pudo verificar un archivo trasladado. Los apuntes de Invitado siguen intactos; vuelve a intentarlo.': 'Could not verify a transferred file. Your Guest notes are still intact; try again.',
  'No se pudo verificar una versión del historial. Los apuntes de Invitado siguen intactos.':
      'Could not verify a history version. Your Guest notes are still intact.',
  'Operación cancelada. Tus archivos se conservan.':
      'Operation cancelled. Your files are preserved.',
  'Selecciona al menos una imagen o documento.':
      'Select at least one image or document.',
  'Selecciona al menos un apunte.': 'Select at least one note.',
  'Selecciona texto de hasta 12000 caracteres.':
      'Select text up to 12,000 characters long.',
  'Un archivo de destino no coincide con el original. Los apuntes de Invitado siguen intactos.': 'A destination file does not match the original. Your Guest notes are still intact.',
  'No se pudo abrir tu biblioteca': 'Could not open your library',
  'Tus datos no se han borrado. Cierra la app, desbloquea el dispositivo y vuelve a intentar.': 'Your data has not been deleted. Close the app, unlock your device, and try again.',
  'Despliega o contrae la lista para revisar los apuntes':
      'Expand or collapse the list to review the notes',
  'Captura para revisar': 'Capture to review',
  'Fuentes analizadas': 'Sources analyzed',
  'El reconocimiento de voz no está disponible. Revisa el permiso de micrófono o escribe tu consulta.': 'Voice recognition is unavailable. Check microphone permission or type your query.',
  'Selecciona solo texto para mejorarlo.': 'Select text only to improve it.',
  'Ocurrió un error. Inténtalo de nuevo.': 'Something went wrong. Try again.',
  'Renombrar apunte': 'Rename note',
  'Analizar fuentes': 'Analyze sources',
  'Importación manual': 'Manual import',
  'Lectura de fuentes con IA': 'AI source reading',
  'Elegir carpeta': 'Choose a folder',
  'Los apuntes y archivos se cifran en el teléfono con una clave protegida por el sistema. Invitado y cada cuenta de Google tienen una bóveda local independiente. Las notas todavía no se sincronizan con la nube.': 'Notes and files are encrypted on this phone with a system-protected key. Guest and each Google account have separate local vaults. Notes are not synced to the cloud yet.',
  'Español (América Latina)': 'Spanish (Latin America)',
  'Google se usa para identificar la cuenta y abrir su bóveda local. Las funciones de IA envían al servicio externo únicamente el contenido que confirmes procesar. Las notas y sus archivos permanecen cifrados en el teléfono hasta habilitar la sincronización en la nube.': 'Google identifies your account and opens its local vault. AI features send only the content you confirm for processing to the external service. Your notes and files remain encrypted on this phone until cloud sync is enabled.',
  'La voz usa el reconocedor del sistema, que puede necesitar red. Cámara y micrófono se solicitan al usarlos. No se incluye publicidad ni analítica de seguimiento.': 'Voice uses the system recognizer, which may require a network connection. Camera and microphone access are requested only when needed. The app has no ads or tracking analytics.',
  'Los archivos que exportas se pueden leer fuera de la aplicación. Limpiar caché elimina las copias temporales de exportación. La papelera permite restaurar notas antes de eliminarlas definitivamente.': 'Exported files can be read outside the app. Clearing the cache removes temporary export copies. You can restore notes from the trash before permanently deleting them.',
  'DraftAI permite crear y organizar notas con texto e imágenes guardadas en el dispositivo. Puedes agruparlas en carpetas, buscar su contenido y exportarlas para compartir. Los planes y precios son demostrativos; no se procesan pagos.': 'DraftAI lets you create and organize notes with text and images stored on your device. Group them into folders, search their content, and export them to share. Plans and prices are for demonstration; no payments are processed.',
  'Revisa cualquier extracción o resumen antes de guardarlo. Los modelos externos pueden cometer errores. Sin API configurada, las demostraciones se identifican expresamente.': 'Review any extraction or summary before saving it. External models can make mistakes. Demonstrations are clearly labeled when no API is configured.',
  'Conserva copias de los apuntes importantes. Al desinstalar se eliminan los datos locales. La aplicación no mantiene copias en un servidor.': 'Keep backups of important notes. Uninstalling removes local data. The app does not keep copies on a server.',
  'En Inicio pulsa Nueva nota o + Nuevo → Escribir nota. Elige una carpeta. El editor guarda automáticamente y permite guardar de forma explícita.': 'On Home, tap New note or + New → Write note. Choose a folder. The editor saves automatically and also lets you save explicitly.',
  'Usa + Nuevo para cámara, imágenes o archivos. Revisa cada elemento y elige carpeta. Gratis guarda las imágenes sin OCR. Puedes añadir archivos también desde el editor.': 'Use + New for the camera, images, or files. Review each item and choose a folder. Free mode stores images without OCR. You can also add files from the editor.',
  'Abre el historial en la esquina superior del apunte. Puedes restaurar una versión anterior. La barra de edición también incluye deshacer y rehacer.': 'Open the history from the top corner of a note to restore an earlier version. The editing toolbar also includes undo and redo.',
  'Desde Más → Herramientas de IA selecciona temas o fechas. Genera un resumen o prepara un prompt para copiar a una herramienta externa.': 'From More → AI tools, choose topics or dates. Generate a summary or prepare a prompt to copy into an external tool.',
  'Restaura desde Papelera. En Exportar elige PDF, Word, texto o Markdown. Almacenamiento permite crear una copia ZIP local.': 'Restore notes from Trash. In Export, choose PDF, Word, text, or Markdown. Storage lets you create a local ZIP backup.',
  'La copia ZIP contiene tus notas e imágenes sin cifrar para que puedas recuperarlas fuera de DraftAI. Guárdala en un lugar protegido.': 'The ZIP backup contains unencrypted copies of your notes and images so you can recover them outside DraftAI. Store it somewhere secure.',
};

String _dynamicEnglish(String value) {
  final move = RegExp(r'^¿Mover (\d+) apuntes a (.+)\?$').firstMatch(value);
  if (move != null) return 'Move ${move[1]} notes to ${move[2]}?';
  final transfer = RegExp(
    r'^Se moverán (\d+) apuntes a la bóveda cifrada de esta cuenta\. Los datos de Invitado solo se retirarán después de verificar la copia\.$',
  ).firstMatch(value);
  if (transfer != null) {
    return '${transfer[1]} notes will move to this account’s encrypted vault. Guest data is removed only after verifying the copy.';
  }
  final available = RegExp(r'^(\d+) apuntes disponibles$').firstMatch(value);
  if (available != null) return '${available[1]} notes available';
  final selected = RegExp(r'^(\d+) seleccionados$').firstMatch(value);
  if (selected != null) return '${selected[1]} selected';
  final insert = RegExp(r'^Insertar (\d+) archivos$').firstMatch(value);
  if (insert != null) return 'Insert ${insert[1]} files';
  final inRange = RegExp(r'^(\d+) apuntes en el rango$').firstMatch(value);
  if (inRange != null) return '${inRange[1]} notes in range';
  final sources = RegExp(r'^(\d+) fuentes en este grupo$').firstMatch(value);
  if (sources != null) return '${sources[1]} sources in this group';
  final sourceConfirmation = RegExp(
    r'^Se enviarán (\d+) fuentes y los nombres de tus carpetas/apuntes al servicio de IA\. Se procesarán en (\d+) grupos de hasta 5\. Revisarás cada destino antes de guardar\.$',
  ).firstMatch(value);
  if (sourceConfirmation != null) {
    return 'This will send ${sourceConfirmation[1]} sources and your folder and note names to the AI service. They will be processed in ${sourceConfirmation[2]} groups of up to 5. You can review each destination before saving.';
  }
  final countOf = RegExp(r'^(\d+) / (\d+)$').firstMatch(value);
  if (countOf != null) return '${countOf[1]} of ${countOf[2]}';
  final quota = RegExp(r'^(\d+) de (\d+) usos · (\d+) disponibles$')
      .firstMatch(value);
  if (quota != null) {
    return '${quota[1]} of ${quota[2]} uses · ${quota[3]} available';
  }
  final remainingUses = RegExp(r'^(\d+) usos disponibles$').firstMatch(value);
  if (remainingUses != null) return '${remainingUses[1]} uses available';
  final serverQuota = RegExp(r'^Servidor: (\d+) de (\d+) llamadas disponibles$')
      .firstMatch(value);
  if (serverQuota != null) {
    return 'Server: ${serverQuota[1]} of ${serverQuota[2]} calls available';
  }
  final deleteSelected = RegExp(
    r'^Se eliminarán (\d+) apuntes seleccionados y sus archivos\. Esta acción no se puede deshacer\.$',
  ).firstMatch(value);
  if (deleteSelected != null) {
    return 'Permanently delete ${deleteSelected[1]} selected notes and their files? This cannot be undone.';
  }
  final viewNotes = RegExp(r'^Ver (\d+) apuntes$').firstMatch(value);
  if (viewNotes != null) return 'View ${viewNotes[1]} notes';
  final libraryFailure = RegExp(r'^No se pudo abrir la biblioteca: .+$')
      .firstMatch(value);
  if (libraryFailure != null) return 'Could not open the library. Try again.';
  final rangeSummary = RegExp(
    r'^(\d+) apuntes · (\d+) carpetas · (\d+) en papelera$',
  ).firstMatch(value);
  if (rangeSummary != null) {
    return '${rangeSummary[1]} notes · ${rangeSummary[2]} folders · ${rangeSummary[3]} in trash';
  }
  final formatPreview = RegExp(r'^Vista previa de (PDF|Word)$')
      .firstMatch(value);
  if (formatPreview != null) return '${formatPreview[1]} preview';
  final version = RegExp(r'^Versión (.+) · Build (\d+)$').firstMatch(value);
  if (version != null) return 'Version ${version[1]} · Build ${version[2]}';
  final price = RegExp(r'^\$(\d+(?:\.\d{2})?) / mes$').firstMatch(value);
  if (price != null) return '\$${price[1]} / month';
  final revision = RegExp(r'^(\d{2}/\d{2}/\d{4}) · (.+)$').firstMatch(value);
  if (revision != null) {
    final reason =
        <String, String>{
          'Edición': 'Edit',
          'Resumen de IA': 'AI summary',
          'Restauración de historial': 'History restore',
          'Importación': 'Import',
        }[revision[2]] ??
        revision[2];
    return '${revision[1]} · $reason';
  }
  final reviewedSources = RegExp(r'^Fuentes revisadas · (.+)$')
      .firstMatch(value);
  if (reviewedSources != null) {
    return 'Reviewed sources · ${reviewedSources[1]}';
  }
  final batchQuota = RegExp(
    r'^Este lote necesita (\d+) acciones y quedan (\d+)\. Reduce el lote o espera al próximo día\.$',
  ).firstMatch(value);
  if (batchQuota != null) {
    return 'This batch needs ${batchQuota[1]} actions, but only ${batchQuota[2]} remain. Reduce the batch or wait until tomorrow.';
  }
  final cacheCleared = RegExp(r'^Caché temporal limpia: (.+) liberados\.$')
      .firstMatch(value);
  if (cacheCleared != null) {
    return 'Temporary cache cleared: ${cacheCleared[1]} freed.';
  }
  return value;
}
