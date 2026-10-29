# Compartir operaciones cerradas ya enviadas

La selección para compartir incluye todas las operaciones cerradas que aún no
tienen copia de salida registrada. Las activas continúan excluidas.

Una operación con envio=1 e idNube positivo puede viajar como copia ya confirmada.
Si hay una huella confirmada local, debe coincidir con el contenido compartido;
un estado inconsistente no se toma como confirmación del contenido actual.

La maestra guarda esta copia en LocalTransfers con status=cloud y el ID recibido.
Se incluye en sus reportes locales. Su sincronizador omite la copia sin llamar a
la API: no hay POST, PUT ni consulta adicional de nube por este traspaso.
La confirmación procede de la tablet operadora; no es una nueva verificación online.

UUID y huella impiden duplicar la copia al repetir una entrega a la misma maestra.
Un ID de nube distinto en una copia existente se informa como conflicto.
Las operaciones con envio pendiente, incluso si ya tienen idNube, conservan su
recorrido normal de actualización y confirmación.

No hay migración nueva de SQLite ni cambios de backend para esta función.
Se requiere la app actualizada en operadora y maestra.
