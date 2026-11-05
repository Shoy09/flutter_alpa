# Dictado de labor en Taladro Largo (Android)

En el formulario de perforación, pulsar el micrófono de Labor, conceder permiso
y decir una labor completa. Hacer una pausa al terminar. El botón rojo cancela.
La escucha tiene un límite de 15 segundos. El valor queda editable y solamente
se guarda cuando el operador pulsa Guardar. Los registros cerrados no permiten dictado.

Ejemplos: «tajo setecientos treinta», «tajo siete treinta» y «tajo siete tres cero»
se convierten en `TJ_730`. «Tajo siete treinta norte» produce `TJ_730_NORTE`.
Las opciones locales ayudan a sugerir labores, pero no son obligatorias.
En esta primera prueba la abreviatura configurada es Tajo → TJ. Otros nombres
se conservan en mayúsculas, separados por guiones bajos, para evitar inventar
abreviaturas del negocio.

El motor Vosk y el modelo español están incluidos en Android. No se envía audio
ni se descarga un modelo al dictar. El primer uso extrae y carga el modelo en el
almacenamiento privado de la app; puede tardar más. Se necesita una instalación
nueva del APK, no basta con hot reload. El micrófono se libera al salir del
formulario o enviar la app al fondo. Esta integración no está habilitada en iOS,
Windows o web.

## Prueba en campo

1. Instalar el APK actualizado y activar modo avión antes del primer dictado.
2. Probar las tres formas de decir 730 y un código que no exista en las opciones.
3. Probar cero inicial, ala norte/sur y corregir el resultado con el teclado.
4. Comprobar permiso denegado, cancelar y cerrar el formulario durante la escucha.
5. Repetir con ruido real de maquinaria; verificar los códigos antes de guardar.

## Modelo y dependencias

- Modelo: `vosk-model-small-es-0.42`, distribuido en
  `android/app/src/main/assets/model-es.zip` (aproximadamente 39 MB comprimidos).
- Fuente: https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
- Catálogo y licencia declarada Apache 2.0: https://alphacephei.com/vosk/models
- Motor Android: `com.alphacephei:vosk-android:0.3.75@aar`.
- JNA: `net.java.dev.jna:jna:5.18.1@aar`.
- La descarga del modelo y las dependencias es necesaria al preparar/compilar,
  con archivos incorporados en el APK para operar sin conexión.
