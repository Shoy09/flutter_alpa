# Sincronización de operaciones por UUID

La base personal Flutter usa versión 4. Las diez tablas de operaciones tienen
sync_uuid (UUID v4 permanente) y sync_retry_safe (marca local, no se envía a la API).
La migración conserva todos los datos, estados y claves existentes. Los registros
históricos reciben sync_retry_safe=0: asignar un UUID no demuestra que un envío
anterior lo haya utilizado.

Antes de cada envío manual y cada ciclo automático se consulta
GET /operaciones/sync-capabilities. Solo ok=true y sync_uuid_version=1 permiten
reintentos de creaciones protegidas. La API comprueba los diez índices UNIQUE en
su propia base. Un timeout, 404, 503 o respuesta inválida deshabilita esos reintentos.
Se conserva la creación inicial compatible con servidores anteriores; si pierde
la confirmación, requiere conciliación porque no tiene protección comprobada.

Cuando el servidor confirma compatibilidad, Flutter persiste sync_retry_safe=1
y envio=2 en la misma transacción, antes del primer POST. Si pierde la respuesta,
los estados 2/3 se pueden recuperar con el mismo UUID. Un ID remoto ya conocido
siempre se recupera mediante PUT, incluso si la app se cerró en estado 2.

Si el POST repetido devuelve reutilizado=true, se guarda el idNube y envio=0.5
para enviar la versión local actual mediante PUT en el siguiente ciclo. Esto
conserva las ediciones que se hicieron después del POST original. La confirmación
incluye el UUID esperado, además de local_id y server_id válidos.

La sincronización automática se dispara al recuperar internet y cada dos minutos
mientras la app puede ejecutar el temporizador y hay conexión. No es un servicio
nativo en segundo plano ni garantiza ejecución con la app cerrada. Manual y
automático conservan el bloqueo común contra solicitudes simultáneas.

## Despliegue pendiente

La migración MySQL ya fue reportada como ejecutada. Se debe desplegar la API con
la creación idempotente y la nueva ruta sync-capabilities en el servidor Azure al
que apunta ApiConfig. La API solo local no protege los envíos dirigidos a Azure.
La ruta nueva no requiere otra migración en MySQL. Flutter migra automáticamente
la base personal al abrirla, sin reinstalar ni borrar los datos de la tablet.

Validar en una base de pruebas POST repetidos y simultáneos, pérdida de respuesta,
ediciones antes de recuperar el ID y PUT posteriores antes de distribuir.
Las pruebas locales usan SQLite en memoria y HTTP simulado; no validan la nube.

## Pendientes antiguos

Los estados 2/3 con sync_retry_safe=0 e idNube=0 requieren conciliación inicial,
como también los registros antiguos marcados como enviados sin ID remoto. No
resetear masivamente envio a cero: pueden existir en la nube sin la nueva clave.