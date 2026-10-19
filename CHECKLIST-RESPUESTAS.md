# Respuestas del checklist de una operación

Las diez pantallas que crean operaciones generan el checklist con `ChecklistRespuesta.desdeCatalogo(item).toMap()`. El catálogo sigue seleccionándose por código y proceso del equipo.

Cada verificación comienza así:

```json
{
  "descripcion": "Verificar aceite",
  "categoria": "Motor",
  "estado_inicio": null,
  "estado_final": null,
  "no_aplica": false,
  "observacion": ""
}
```

- `estado_inicio` y `estado_final`: `"bueno"`, `"malo"` o `null` (pendiente), independientes entre sí.
- `no_aplica`: corresponde al ítem completo. Al activarlo se serializan ambos estados como `null`.
- `observacion`: texto de la verificación.

La pantalla `lib/screens/checklist/checklist_screen.dart` recibe los ítems reales y un callback de persistencia. Cada proceso usa su método `updateCheckList...` actual. Las operaciones cerradas son de solo lectura. Los datos se agrupan por categoría para mostrarlos, pero se guardan en su orden original. No se modifica la lista recibida del padre mientras se edita.

Las respuestas siguen en el campo JSON `check_list` de la operación; no se necesita modificar el esquema SQLite para estos campos. Los exportadores existentes envían ese JSON completo.

## Operaciones anteriores

Al leer el formato antiguo, `decision: 1` se interpreta como inicio bueno y `decision: 0` como inicio malo, siguiendo su significado anterior. El final queda pendiente y las observaciones se conservan. El formato antiguo no permite distinguir si el cero fue una respuesta del operador o el valor inicial que se usaba al crear la operación; no se fabrica un estado final a partir de ese dato.

La lectura no reescribe registros históricos. Si el operador guarda desde la pantalla nueva, se serializan los campos nuevos y se retira `decision`. Otros campos existentes del ítem se conservan.

Los consumidores del JSON en la web o en reportes deben leer los nuevos campos cuando estén presentes; `decision` deja de ser la respuesta de los ítems nuevos. No se cambia el checklist de telemando, que tiene su propio flujo.

El acceso de demostración sin parámetros se conserva para el prototipo existente. Las pantallas de operaciones pasan siempre sus datos y nunca usan los ítems de ejemplo.

## Pruebas

```powershell
flutter test --no-pub test/checklist_respuesta_test.dart test/checklist_screen_test.dart
```
