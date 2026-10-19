# Envío de operaciones

Las diez pantallas manuales de equipos y `SyncService.syncData()` usan el mismo motor y bloqueo en memoria. La vista previa no decide si se crea o actualiza: el motor consulta nuevamente SQLite al entrar al bloqueo.

- `idNube > 0`: PUT a `/operaciones/update-masivo`, incluso con `envio = 0`.
- Sin ID remoto y pendiente: POST a `/operaciones/crear`, conservando `local_id`.
- Se cruza la respuesta de creación por `local_id`, nunca por posición.
- Un HTTP 200 no basta: cada PUT debe devolver `actualizado: true` para el ID remoto.
- El ID remoto y el estado se guardan juntos. Las ediciones locales realizadas durante el envío quedan pendientes de actualizar.

| envio | Significado |
| --- | --- |
| 0 | Pendiente |
| 0.5 | Operación activa sincronizada o actualización pendiente |
| 1 | Operación cerrada confirmada |
| 2 | Lote en tránsito; no reenviar automáticamente |
| 3 | Creación sin confirmación; conciliar con la nube antes de reenviar |

El servidor disponible hace `bulkCreate` sin clave de idempotencia persistida. Si se pierde la respuesta de un POST, repetirlo puede duplicar datos. Por eso no se restaura a 0 una creación incierta. No deben resetearse 2/3 a 0 sin comprobar primero si el servidor creó el registro. Los registros antiguos enviados sin `idNube` y los duplicados ya existentes requieren conciliación; este cambio no los borra ni intenta identificarlos por semejanza.

Para reintentos automáticos seguros después de perder una respuesta se necesita una clave única persistente en el backend que identifique dispositivo/usuario, tipo y registro local. `local_id` por sí solo no es único entre instalaciones.

Explosivos y Mediciones usan endpoints y contratos distintos; no forman parte del sincronizador automático de operaciones de equipos ni del motor anterior.

Pruebas: `flutter test --no-pub test/operation_sync_test.dart`. Utilizan SQLite temporal y HTTP simulado; no envían información al servidor real.
