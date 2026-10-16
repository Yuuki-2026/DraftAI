# Integracion 0.2.0
Base: main 391cc9d. SDK y firma conservados. Google y pagos siguen simulados.

## Reparto
- Integrador: editor con imagenes intercaladas, galeria, PDF, importacion por nota, IA restringida, servidor temporal, localizacion base, pruebas y APK.
- feat/ui-organizacion (otra persona): design.dart, library_page.dart, settings_pages.dart y widgets de carpetas/colores/recientes/formularios/seleccion. Consumir localizacion base. No editar servidor, editor ni persistencia.
- Integrar su PR cuando exista; no darla por terminada sin revisar commits, pruebas y capturas. No esperar para avanzar el bloque principal.

## Criterios
Referencia: Contexto/Mockup/mockup_screens y mockup.css actuales. Las instrucciones del propietario prevalecen sobre textos contradictorios o funciones ficticias del mockup.
Medios dentro del documento en el cursor, sin nombres/cajas de imagen. Lote dirigido a nota existente o nueva; nunca una nota por foto por defecto. Lectura con IA central y herramientas secundarias ocultas. Conservar notas e historial anteriores.
Claves de proveedor fuera del repositorio y del APK. Servidor temporal de pruebas con emparejamiento por dispositivo, limites y validacion de entradas/salidas. Solo resumir, mejorar y analizar imagenes; sin chat ni herramientas libres.

## Merge previsto
Preparacion -> integration/v0.2.0; feat/ui-organizacion -> integration; bloque principal -> integration; verificaciones conjuntas -> main; etiqueta v0.2.0 y APK firmado con SHA-256.
