# Resumen de producción recibida

Entrada desde MASTER: Transferencias sin internet → Resumen de operaciones recibidas.
Lectura exclusiva de LocalTransfers con direction=inbox; no modifica originales,
estados de sincronización ni copias. No requiere API ni nuevas migraciones.

Filtros combinados: fecha operativa, turno, operación y equipo. Antes de las 06:00
se selecciona NOCHE del día anterior; 06:00 inicia DÍA y 18:00 inicia NOCHE.
Al cambiar fecha, turno u operación se restablece el equipo para evitar filtros
incompatibles. Restablecer vuelve al turno actual y a todas las operaciones/equipos.

Los contadores y la distribución cuentan copias de operaciones. Las tablas y sus
totales cuentan datos de producción, con unidades separadas por proceso.

Reglas implementadas en production_report.dart:

- Scoop: códigos 101, 102, 105, 106, 108; agrupa por equipo, labor, destino y
  material; suma cucharas. No infiere toneladas sin capacidades verificadas.
- Horizontal: estado OPERATIVO, labor/tipo presentes, duración positiva y metraje
  positivo. (Producción+rimados+alivio) × long_barras en pies × 0,3048 × n_barras.
  Solo ausencia de n_barras implica 1; cero no se convierte en 1. La duración
  contempla medianoche. Agrupa condiciones equivalentes incluyendo equipo y barras.
- Taladro largo: elementos de operacion.barras; longitud_perforacion positiva,
  y tipo requerido si n_fila > 0. Metraje directo, sin multiplicarlo por barras.
  Conserva la regla del ejemplo sin filtro de estado. Las copias actuales no
  tienen un campo independiente de longitud de barra, por lo que no se inventa.
- Scalamin: OPERATIVO; área y metros lineales independientes, filas con datos útiles.
- Sostenimiento: OPERATIVO; listas perno/malla/perforacion alineadas por índice,
  con soporte de objetos de versiones anteriores. No repite elementos para llenar
  listas desiguales. Metros de pernos = cantidad × longitud en pies × 0,3048.
  Totales de pernos, metros de pernos, malla MT52, taladros y longitud perforada.

No se incluyen porcentajes de disponibilidad/utilización ni indicadores con
definiciones pendientes. Otras operaciones conservan listado y estado de sus
copias, sin inventar tablas productivas. El historial conserva el contenido completo.

Tablas con páginas de diez filas y desplazamiento horizontal para columnas amplias.
Los totales usan todas las filas filtradas, no solamente la página visible.
La pantalla muestra el último momento de actualización; refrescar vuelve a SQLite.

Validación: 14 pruebas focalizadas de fórmulas, filtros, medianoche y visualización
a 390 y 1366 píxeles, además del análisis estático sin incidencias. Vista previa
generada con datos ficticios en build/received_dashboard_preview.png.
