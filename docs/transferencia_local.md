# Transferencia a una tablet maestra sin internet

## Uso

1. Actualizar las apps sobre la instalación existente, con el mismo ID y firma.
   No desinstalar ni borrar los datos. La base personal migra a versión 5.
2. Activar manualmente el punto de acceso Wi-Fi de la maestra con contraseña.
   No necesita SIM, datos móviles ni router, si el modelo admite ese modo.
3. En la maestra, entrar con rol Master. Abrir el icono Wi-Fi del panel y pulsar
   **Iniciar recepción**. Elegir la IP que corresponda al punto de acceso.
4. En cada tablet, conectarse a esa Wi-Fi y mantener la conexión sin internet.
   Abrir Transferencias, introducir IP y código de ocho dígitos y pulsar
   **Enviar y recoger confirmaciones**. El puerto local es 47831.
5. Mantener la pantalla de recepción abierta. Android solicita mantenerla
   encendida durante la sesión; no es un servicio en segundo plano.
6. Al disponer de internet, la maestra o el origen pueden subir/confirmar. Se
   utiliza el mismo flujo automático existente y el botón de la pantalla.
7. Si el origen no obtiene internet, al entregar al día siguiente recibe también
   las confirmaciones de los registros que la maestra ya subió.

La primera versión usa IP y código, sin escáner QR ni activación automática del
punto de acceso. Windows puede requerir permitir conexiones entrantes en su
firewall de red privada. No se cambia el firewall automáticamente.

## Datos y estados

Solo operaciones cerradas de los diez tipos operativos sincronizados con la
nube: tal largo/horizontal, empernador, carguío, rompebanco, Scissor, Anfochanger,
Scalamin, Dumper y Volquetes. No incluye explosivos, mediciones ni otros módulos.
El checklist de telemando está excluido, según indicación del usuario.

Las copias viajan con UUID original, ID remoto conocido y todo el contenido de
negocio definido por el exportador. La maestra las guarda en una bandeja separada
LocalTransfers dentro de la base del usuario Master. No mezcla IDs locales de
operadores ni modifica los catálogos o credenciales de la maestra. Se pueden
inspeccionar desde Transferencias; no se insertan en las pantallas de producción.

- Preparado: copia local durable lista para entregar; no prueba recepción.
- Entregado: maestra confirmó haber guardado la copia en SQLite.
- Recibido: bandeja de la maestra pendiente de nube.
- Confirmado en nube: la nube conserva esa misma operación cerrada y contenido.
- Requiere revisión: se encontró una diferencia; no se sobrescribe ni elimina.

Recibir en la maestra no cambia envio a 1 en el origen. La confirmación exacta de
la nube o el recibo posterior de la maestra sí asignan idNube y envio=1, después
de comprobar que el contenido local sigue igual. Una operación transferida queda
fuera de POST/PUT habituales: usa exclusivamente confirmación de cerrado. Si se
edita después de transferir, se conserva el snapshot y la edición, y se bloquea
su envío automático hasta revisión. No se ofrece sobrescritura automática.

Repetir una transferencia con el mismo UUID/contenido devuelve su recibo. Otra
versión del mismo UUID devuelve conflicto y mantiene el original en la maestra;
la tablet remitente conserva su propia versión. Los pendientes históricos sin ID remoto ni protección confirmada también se
copian a la maestra, pero quedan como “Copiado; pendiente de conciliación”.
Se resguardan sin intentar crearlos en la nube hasta revisar si ya existen.

## Backend y despliegue

Se agregó POST `/operaciones/confirm-closed-transfer` en el backend local. Valida
UUID, estado cerrado y SHA-256 del contenido normalizado. Crea si no existe; si
existe, compara bajo transacción/bloqueo. Solo confirma si contenido y estado
coinciden. No ejecuta PUT ni sobrescribe un cerrado diferente o un activo.
El ID conocido se verifica para impedir asociar otro UUID al registro.

La huella ignora IDs, envio, Hora_envio y campos administrativos. Normaliza claves
de objetos y representación de números enteros, conservando orden de arrays y
contenido real. Flutter y Node comparten vectores de prueba para los diez tipos.

Desplegar el backend actualizado ANTES de usar transferencias en producción.
La ruta de capacidades anunciará `closed_transfer_version: 1`. No hay una nueva
migración de MySQL para esta función; utiliza los índices sync_uuid ya creados.
La migración de telemando que se llegó a preparar fue retirada y no se ejecutó.
Un servidor antiguo/404 deja la transferencia pendiente, sin confirmar ni
reenviar mediante un PUT alternativo. No se desplegó Azure desde esta sesión.

## Pruebas y límites

Se verificaron 15 remitentes simultáneos con sockets HTTP reales en loopback,
SQLite independiente por remitente, repetición tras perder el recibo, reapertura
de la base maestra en disco, fallo de guardado, código incorrecto, datos alterados,
API antigua, ambos órdenes de subida, confirmación sin internet del origen,
ediciones durante la red y conflictos con nube. También se probaron los diez
exportadores reales y las pantallas de operador/maestra mediante widgets.

Las pruebas de nube del nuevo endpoint son aisladas, no contra Azure desplegado.
No equivalen a 15 dispositivos físicos: falta medir cinco minutos con los datos
reales y verificar alcance, aislamiento de clientes y máximo de conexiones de
la maestra. El servidor acepta hasta 16 solicitudes en curso y hasta 2 MiB por
operación; los errores conservan las copias para reintento. No transfiere archivos
externos a los datos exportados. Las copias no se borran automáticamente.

La sesión usa HTTP local protegido por la red Wi-Fi y un código temporal. Usar
una Wi-Fi propia con contraseña. No usar la recepción en una red pública.
El código cambia al iniciar una nueva sesión. Los intentos fallidos se limitan.

Para iniciar la prueba de campo: dos tablets, una operación cerrada nueva,
transferir sin internet, repetir, subir desde la maestra y confirmar en el origen
por ambas vías. Después ampliar a 15 tablets y registrar duración real.

## Resultado de verificación

Pruebas ejecutadas en Windows, sin emulador Android. Se aprobaron las pruebas
unitarias, de widgets, de contrato y de sockets locales. Las 15 conexiones de
prueba son procesos/clientes lógicos sobre loopback, no 15 tablets físicas.
El primer intento de compilación APK se detuvo; el diagnóstico offline encontró
un artefacto Flutter Android arm64 de depuración sin caché. Por indicación del
usuario se continúa la validación en Windows; Android no se declara validado.

Resultado final: 77 pruebas Flutter aprobadas y 45 pruebas de backend aprobadas.
Compilación Windows debug completada; ejecutable en
build/windows/x64/runner/Debug/i_miner.exe. No se desplegó el backend nuevo.

## Listas previas a la transferencia

La pantalla separa Operaciones cerradas disponibles de Historial de transferencias.
La primera consulta solo metadatos locales: no prepara paquetes ni cambia envio.
Excluye activas, cerradas ya confirmadas en nube y operaciones con copia de salida
ya registrada. Las históricas sin confirmación aparecen como copia para conciliación.
Actualizar listas vuelve a consultar; el historial sigue mostrando entregas y recibos.
Esta mejora pasó 19 pruebas focalizadas y análisis sin problemas.

## Conexión mediante QR

La maestra muestra un QR por cada dirección IPv4 privada al iniciar recepción.
Contiene exclusivamente identificador de formato, versión, IP, puerto 47831 y
código de sesión. La operadora usa «Escanear QR de la maestra» dentro de I-MINER;
se completan los campos y el envío requiere pulsar el botón habitual.
No conecta automáticamente al Wi-Fi: ambas tablets deben estar previamente en
la misma red local, sin necesidad de internet.

La IP puede cambiar al reiniciar el punto de acceso; se recuerda la última IP
por usuario, sin guardar el código. Cada nueva recepción genera otro código.
Durante una misma recepción no hace falta escanear por cada operación.
El QR se genera y lee localmente. Se usa MLKit incluido en la app Android,
sin activar el modo de descarga de modelo. Windows permite mostrar el QR y
conectar manualmente; no se ofrece cámara en Windows.

Se rechazan formatos ajenos, IP públicas, códigos incorrectos y versiones o
puertos incompatibles. No hay cambios en tablas ni en los paquetes operativos.
La lectura de cámara requiere validación en una tablet Android física.
