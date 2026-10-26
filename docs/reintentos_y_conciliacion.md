# Revisión de bloqueos y respuestas perdidas

La revisión detectó huecos reales en el cierre mediante maestra con una sola
huella confirmada. Las pruebas anteriores no cubrían respuesta perdida seguida
de nuevas ediciones ni la resolución desde pantalla de copias apartadas del envío normal.

## Intentos persistidos antes de la red

`SyncAttempts` guarda tipo, UUID y huella de cada payload dentro de la transacción
que reclama la operación. La escritura debe completarse antes del POST/PUT.
Los reintentos normales y las copias para maestra llevan `attempted_hashes`.
La API admite una versión remota que coincida con la base confirmada o con uno de
esos intentos; sigue rechazando datos distintos introducidos desde otro cliente.
El conjunto de intentos no permite reabrir una operación cerrada con un PUT activo.

Una confirmación con huella válida elimina huellas anteriores no necesarias y
conserva la huella coincidente. No se borran intentos que siguen sin confirmación.
Esto cubre tanto PUT aplicado sin respuesta como POST aplicado sin respuesta y
posterior entrega de la copia cerrada a la maestra, conservando UUID y el ID remoto.

## Conciliación desde la app

Transferencias sin internet → Historial → abrir copia pendiente → Conciliar con nube.

Disponible para copias pendientes, por conciliar o en conflicto, incluso si se
encuentran excluidas del envío normal. Necesita internet para consultar la nube.
En el operador usa el contenido actual del original cerrado; en la maestra usa
la copia que recibió. No inventa datos que no estén presentes en esa copia.

- Si ya existe la misma versión, se recupera la confirmación.
- Si existe otra versión, se muestran ambas y se exige elegir explícitamente la
  copia local antes de actualizar.
- Si no aparece el UUID, se exige verificar ausencia real, incluidas posibles
  copias antiguas sin UUID. Esa verificación humana sigue siendo necesaria.

La API compara, bajo bloqueo de fila, la huella remota que el usuario revisó con
la vigente al confirmar. Si cambió, no fuerza el reemplazo y pide consultar de nuevo.
Para registros ausentes vuelve a comprobar la identidad con el índice único.
Flutter archiva las versiones revisadas en `SyncReviewHistory` antes de la petición.
Una respuesta perdida durante la conciliación también se puede consultar otra vez.
Se verifica el contenido guardado antes de devolver una confirmación.

No se cambia automáticamente una versión en conflicto por la versión de nube,
ni se declara enviado un original modificado mientras esperaba la respuesta.

## Otros ajustes

- Recuperación individual de estados antiguos 2 y 3 con UUID y sin ID de nube,
  dentro del mismo bloqueo que manual/automático, tras consultar nuevamente la API.
- Las copias ya transferidas se resuelven en conciliación; no se elimina su copia
  ni se las libera a ciegas por el botón de recuperación normal.
- Lista de disponibles y preparación coinciden para `envio` nulo; la carga normal
  también contempla `envio` vacío/nulo.
- Diez códigos incorrectos aplican un enfriamiento de 30 segundos por IP; no
  necesitan reiniciar la maestra. La sesión nueva limpia los contadores.
- No se implementó un servicio Android en segundo plano: mantener la recepción
  abierta sigue siendo un requisito operativo. No se valida Android físicamente.

## Despliegue y validación

Migración personal SQLite v7: crea `SyncAttempts` y `SyncReviewHistory`, sin borrar
operaciones, UUID, idNube ni copias anteriores. No añade columnas a la nube.
Desplegar API antes de instalar APK en ambas tablets. Capabilities debe informar
`retry_versions_version: 1` y `transfer_review_version: 1`.

77 pruebas Flutter y 69 pruebas Node aprobadas. Incluyen los servicios reales
Flutter/Node por HTTP local, dos bases SQLite independientes, pérdidas de respuestas
POST y PUT, nuevas ediciones, cierre por maestra, confirmación local posterior,
conciliación desde pantalla y enfriamiento de código incorrecto sin esperas reales.
La persistencia del servidor de pruebas es en memoria; no se modificó Azure/MySQL
de producción ni se generó/desplegó un APK nuevo como parte de esta verificación.
