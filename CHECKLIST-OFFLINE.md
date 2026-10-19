# Catálogo de checklist por equipo sin conexión

La identidad de un equipo para estas asignaciones es su **código + proceso**, no su ID local ni su nombre. El código debe identificar al equipo dentro del proceso. Si cambia ese código o su proceso en la nube, hay que volver a descargar equipos y checklist para obtener las asignaciones nuevas.

## Datos locales

- `checklist_items`: una fila por ítem. Conserva proceso, categoría y nombre; agrega `aplica_todos_equipos`, `proceso_clave` y `api_id` como referencia del ítem de la nube.
- `checklist_item_equipos`: una fila por asignación. Guarda `equipo_codigo` y `equipo_proceso` como texto, sus claves normalizadas y el ID **local del ítem**. No tiene FK ni ID que apunte a la tabla `Equipo`.
- El nombre de equipo no es clave: equipos con nombres iguales pueden tener códigos diferentes.
- Las claves normalizadas permiten comparar sin diferencias por mayúsculas, tildes o espacios en los extremos.

La base compartida pasa de versión 1 a 2. SQLite agrega las columnas y la tabla al abrir una instalación existente. Los ítems antiguos se conservan como generales de su proceso hasta que se vuelva a descargar el catálogo actualizado. No cambia la versión de la base de datos de usuario.

## Descarga

Se sigue usando el endpoint de checklist completo. La respuesta nueva debe incluir:

```json
{
  "id": 25,
  "proceso": "PERFORACIÓN HORIZONTAL",
  "categoria": "ANTES",
  "nombre": "Verificar aceite",
  "aplica_todos_equipos": false,
  "equipo_ids": [120],
  "equipos": [
    { "id": 120, "codigo": "J-01", "proceso": "PERFORACIÓN HORIZONTAL" }
  ]
}
```

Los IDs de equipos de la nube se usan únicamente para comprobar que la respuesta contenga todas las asignaciones; no se relacionan con IDs locales. Si la API devuelve solo IDs o faltan códigos/procesos, se rechaza la descarga y se conserva el catálogo anterior. No hace falta que los equipos se descarguen antes que el checklist.

El JSON anterior sin alcance ni asignaciones sigue interpretándose como general de su proceso. Un ítem específico sin asignaciones no se vuelve general.

El reemplazo de ítems y asignaciones se realiza en una única transacción. Un error HTTP, de validación o de inserción no deja la aplicación con un catálogo vacío o parcial. Una lista vacía válida de la API sí vacía el catálogo.

## Uso

```dart
final items = await DatabaseHelper().getCheckListByProceso(
  'PERFORACIÓN HORIZONTAL',
  codigoEquipo: codigoSeleccionado,
);
```

Devuelve los generales del proceso y los asignados al código solicitado. Si falta el código, devuelve únicamente generales, para no exponer verificaciones de otros equipos.

Las diez pantallas de creación de operaciones utilizan ahora el código seleccionado. Cada operación sigue guardando su propia copia JSON del checklist: sus decisiones y observaciones ya registradas no cambian al actualizar el catálogo. El prototipo DEMO de `lib/screens/checklist` no se modifica.

Después de actualizar la aplicación: descargar nuevamente **Checklist** desde la nube para recibir las restricciones por equipo. La migración por sí sola no puede deducir asignaciones que la copia antigua no contenía.

## Pruebas

```powershell
flutter test --no-pub test/checklist_catalog_test.dart
```

Usan SQLite en memoria y respuestas HTTP simuladas, sin acceder a la base local de los usuarios ni al servidor.
