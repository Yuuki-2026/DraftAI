import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/presentation/controller.dart';

final localeProvider = AsyncNotifierProvider<LocaleController, String>(
  LocaleController.new,
);

class LocaleController extends AsyncNotifier<String> {
  @override
  Future<String> build() async =>
      await ref.read(notesPort).preference('locale') ?? 'es';
  Future<void> change(String value) async {
    if (!['es', 'en'].contains(value)) return;
    await ref.read(notesPort).setPreference('locale', value);
    state = AsyncData(value);
  }
}

String tr(BuildContext context, String es) =>
    Localizations.localeOf(context).languageCode == 'en'
    ? english[es] ?? es
    : es;
const english = <String, String>{
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
  'Original': 'Original',
  'Contenido modificado. Vuelve a seleccionar el texto.':
      'Content changed. Select the text again.',
  'Conectar IA de prueba': 'Connect test AI',
  'Código de conexión': 'Connection code',
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
