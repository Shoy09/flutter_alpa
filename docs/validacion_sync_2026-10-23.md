# Validación de sincronización — 23 de octubre de 2026

## Resultado

- 44 pruebas aisladas aprobadas: motor de sincronización, migración de identidad,
  exportador Scissor y reglas de edición de horarios en seis formularios.
- 10 pruebas de integración aprobadas contra la API Azure configurada en Flutter.
- 20 registros identificados como CODEX_SYNC_TEST fueron creados, verificados
  directamente en MySQL y eliminados usando exclusivamente UUID + operador.
- MySQL confirmó una sola fila por cada UUID, el mismo ID devuelto por Azure,
  estado cerrado y el contenido actualizado de registros en las 20 filas.

## Escenarios reales en las diez clases de operación

Tal largo, horizontal, empernador, carguío, rompebanco, Scissor, Anfochanger,
Scalamin, Dumper y Volquetes. Se utilizaron los exportadores de la app y su motor
real con SQLite en memoria, sin modificar la base personal de la app abierta.

1. Crear en Azure y descartar la respuesta recibida para simular su pérdida.
2. Comprobar envio=3 y marca de reintento protegido en SQLite.
3. Editar localmente antes de recuperar el ID.
4. Reenviar el mismo UUID y recuperar el ID de la creación original.
5. Enviar PUT con la versión local actual y confirmar envio=1.
6. Repetir la sincronización de un registro confirmado sin volver a enviarlo.
7. Enviar dos POST concurrentes con un UUID nuevo: ambos devuelven el mismo ID.
8. Recuperar y actualizar también ese segundo registro; verificar en MySQL.

Las pruebas aisladas cubren además estados 2 interrumpidos, bloqueos de registros
antiguos, compatibilidad no disponible, confirmación con UUID equivocado,
respuestas parciales, errores por fila y serialización manual/automática.

## Límites de esta validación

No se manejó la ventana de Windows con ratón/teclado ni se verificó el circuito
completo de navegación. Las pruebas de formulario cubren reglas de horarios, no
todos los campos y pantallas. No se cerró ni reinició la app del usuario, ni se
esperó el temporizador automático de dos minutos: se llamó al motor compartido.
La pérdida se simuló descartando una respuesta real, sin cortar la red del PC.
No se probaron suspensión ni ahorro de batería de Android.

Estas pruebas no garantizan ausencia de errores en escenarios o datos no cubiertos.

## Repetir la integración

La prueba normal queda omitida; requiere autorización explícita por escribir
en el servidor real. Verificar primero que se pueda limpiar la misma base:

```powershell
node tool/verify_live_sync.cjs probe
flutter test test/operation_sync_azure_test.dart --no-pub --dart-define=RUN_AZURE_SYNC_TESTS=true --concurrency=1
node tool/verify_live_sync.cjs verify build/sync-live-manifest.json
node tool/verify_live_sync.cjs cleanup build/sync-live-manifest.json
```

Ejecutar cleanup también si la integración falla. El manifiesto se escribe antes
de cada POST y la prueba impide sobrescribir un manifiesto sin limpieza confirmada.
El script usa config/config.json (development) del backend local; SYNC_BACKEND_ROOT
permite indicar su carpeta. No debe usarse contra otra base distinta de Azure.
