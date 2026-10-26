# Actualización y cierre mediante la maestra

## Recorrido

1. El operador envía una operación activa directamente por internet.
2. La API devuelve su ID y `cloud_hash`, calculado sobre los datos que realmente
   conserva la nube. Flutter guarda ambos de forma transaccional.
3. El operador continúa trabajando, cierra y entrega la copia a la maestra.
   El paquete conserva UUID/ID y lleva `base_cloud_hash` como metadato.
4. La maestra usa `confirm-closed-transfer`. En una transacción con bloqueo de fila,
   la API verifica UUID, identidad y que la operación activa siga coincidiendo con
   la versión base. Actualiza los datos operativos y el estado a cerrado sobre el
   mismo ID; conserva campos administrativos ajenos al contrato.
5. La maestra conserva el recibo. El operador obtiene ID/envio=1 en el siguiente
   traspaso local, o mediante su propia conexión a internet.

## Protección de versiones

- Una respuesta perdida se reintenta con el mismo UUID. Una copia cerrada idéntica
  devuelve el ID existente; no se crea otra ni se vuelve a sobrescribir.
- Cambios remotos posteriores a la base producen conflicto, sin reemplazo.
- Dos maestras con cierres distintos no pueden reemplazar sucesivamente el cierre.
- UUID/ID de otra operación o identidad de operador/equipo distinta se rechazan.
- Un PUT activo atrasado no puede reabrir una operación ya cerrada.
- Los PUT normales con base verifican la versión. Si el contenido ya es idéntico,
  pueden confirmar un reintento aun cuando la base sea anterior.
- POST reutilizado devuelve la huella de la fila existente, no la del intento nuevo.
- Si hubo ediciones locales durante una petición, se conserva la huella del contenido
  realmente confirmado y la edición queda pendiente.

La transferencia entre tablets continúa aceptando únicamente operaciones cerradas.
No implementa versiones activas entregadas sucesivamente a la maestra.

## Migración y despliegue

Flutter usa versión 7 de la base personal. `_onUpgrade` llama a
`OperationSyncIdentity.migrate` para añadir `sync_cloud_hash TEXT` nullable a las
diez tablas. No cambia UUID, datos, ID de nube ni estados existentes.
No hace falta una migración nueva en la BD de nube para esta función.

Desplegar primero el backend y comprobar `/api/operaciones/sync-capabilities`:
debe incluir `active_close_transfer_version: 1`. Después instalar el APK actualizado
en operadores y maestra. Este trabajo modifica código local; no despliega Azure.

Registros históricos sin huella: no se inventa una base ni se toma automáticamente
la versión remota actual como permiso para sobrescribir. Si solamente cambió estado,
la API puede cerrar. Si además cambió contenido, requiere conciliación. Para adquirir
huellas en el recorrido normal se necesita una confirmación online de la API nueva.
Los conflictos históricos pueden consultarse mediante «Conciliar con nube» en el
detalle de la transferencia. Véase `reintentos_y_conciliacion.md` para el historial
de intentos, recuperación y controles de la conciliación explícita.

## Validación

Pruebas de backend para las diez operaciones: activo → edición online → copia final
cerrada, mismo ID, reintento, cambios remotos, dos maestras y PUT activo atrasado.
Persistencia simulada; no son pruebas contra MySQL/Azure de producción.

`active_close_transfer_test.dart` comprueba migración idempotente y un recorrido real
de HTTP entre Flutter y los servicios Node locales, con dos bases SQLite independientes
y persistencia Node en memoria: POST activo, edición mientras llega la respuesta,
entrega LAN, cierre por maestra y confirmación posterior al operador sin internet.
Los puertos son de loopback y no se usan credenciales ni datos de producción.
