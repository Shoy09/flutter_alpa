# Corrección de envíos nuevos bloqueados (SYNC-20261024-R2)

## Falla del código anterior

La comprobación de compatibilidad devolvía false si superaba cinco segundos o
fallaba la conexión. SyncService pasaba ese false al motor, pero el motor todavía
permitía POST nuevos sin persistir sync_retry_safe=1. Una pérdida de respuesta
posterior dejaba envio=3, sync_retry_safe=0, incluso en operaciones creadas ese día
con UUID. El siguiente intento las excluía y mostraba un mensaje que sugería que
eran antiguas. Las pruebas anteriores no cubrían ese primer fallo de capacidad.

La captura por sí sola no confirma los valores guardados en esa tablet. Esta
ruta sí se identificó en el código y se agregó su regresión específica.

## Corrección

- El motor exige por defecto compatibilidad antes de crear. Un fallo del probe
  no inicia POST, conserva envio=0 y señala el envío como pendiente.
- La comprobación admite 15 segundos. Las actualizaciones por ID remoto siguen
  funcionando aunque la comprobación UUID falle.
- Antes de un POST protegido, envio=2 y sync_retry_safe=1 se guardan atómicamente.
- Los registros 2/3 sin protección se consultan por UUID mediante lookup-sync
  cuando la API anuncia compatibilidad. Esa ruta nunca crea ni modifica filas.
- Contenido idéntico recupera idNube y confirma el estado. Si la nube aún está
  activa y coinciden UUID, fecha, turno, operador y equipo, recupera el ID pero
  deja envio=0.5: el PUT habitual debe confirmar el contenido actual y el cierre.
  Un cerrado distinto o una identidad diferente quedan en conflicto, sin sobrescribir.
- Un UUID ausente no demuestra ausencia de una copia histórica sin UUID: no se
  resetea automáticamente. El diálogo permite recuperación individual después
  de marcar que se verificó ausencia en la nube. El servicio vuelve a consultar
  el UUID antes de resetear, usa el mismo UUID y rechaza cambios concurrentes,
  IDs ya conocidos y registros que estén en una transferencia.
- Las respuestas HTTP rechazadas muestran código y motivo, y el diálogo permite
  copiar el detalle. Los errores incluyen la marca SYNC-20261024-R2 para distinguir
  el código corregido de paquetes anteriores; no es el versionCode del APK.

## Despliegue necesario

1. Publicar el backend local actualizado con POST /operaciones/lookup-sync.
2. Verificar que /api/operaciones/sync-capabilities incluya lookup_sync_version=1.
3. Compilar y distribuir el APK corregido con la misma firma/ID de aplicación.
   Instalar sobre la app existente, sin desinstalar ni borrar datos.
4. Probar primero en una tablet afectada. No se declara solucionado en las tablets
   hasta comprobar allí el registro y su confirmación en nube.

No hay nueva migración MySQL ni SQLite. Un servidor anterior responde 404 a la
consulta nueva: Flutter conserva los registros y muestra el error, sin crear
mediante un endpoint alternativo. No se desplegó Azure desde esta sesión.

No es una atribución del problema a un APK viejo. La corrección anterior estaba
incompleta; para que el cambio de lógica llegue al dispositivo hay que distribuir
un paquete que contenga esta revisión.
