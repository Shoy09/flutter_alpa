# Taladro largo: importación con Gemini integrada en tu API

La implementación principal está ahora en tu backend existente:

C:\Trabajo\nuevo 4\Api-Node\Backend

No necesitas publicar un servidor adicional. Se añadió la ruta:

POST /api/tal-largo/preview

La app usa por defecto la misma ApiConfig.baseUrl más /tal-largo/preview. La URL
ya está en lib/config/api/api_config.dart. PHOTO_IMPORT_URL permite reemplazarla
opcionalmente al compilar. La clave de Gemini nunca se configura en Flutter.

## Qué falta para activarlo

1. Crear la clave de Gemini en Google AI Studio.
2. Configurar en el servidor/Azure de tu API:

```dotenv
GEMINI_API_KEY=clave_secreta_del_servidor
GEMINI_MODEL=modelo_con_imagenes_y_json_disponible_en_tu_proyecto
PHOTO_IMPORT_DAILY_LIMIT=50
```

3. Publicar y reiniciar el backend actualizado. Si hay un proxy, permitir 12 MB
   y al menos 100 segundos para esta ruta.
4. Compilar e instalar la nueva APK usando la URL habitual de tu API:

```powershell
flutter build apk
```

5. Probar una hoja real como master: cámara/galería → Leer con Gemini → comparar
   y corregir → marcar revisión → Crear registro.

Estado: **código local integrado y probado con respuestas simuladas; todavía no
publicado ni activado con una clave real**. No se modificó el .env de tu API,
ni se enviaron fotos a Gemini. Sin clave/modelo, la API inicia normalmente y
solo la ruta de fotos devuelve 503, que la app muestra como función no habilitada.

La guía técnica completa está en Backend/GEMINI-TAL-LARGO.md.
El backend no necesita migraciones ni dependencias npm adicionales.

## Comportamiento de la app

- Solo master. El backend comprueba el JWT y el rol/estado actual en la BD.
- Foto JPG/PNG hasta 8 MB. Una lectura devuelve datos, nunca crea operaciones.
- Foto ampliable y cabecera, actividades agrupadas con taladros y horómetros editables.
- Lee los horómetros inferiores: H. motor → diésel, percusión y eléctrico,
  con inicio/final y sus decimales, aunque las columnas de las actividades estén vacías.
- Los datos dudosos quedan pendientes. El master debe revisar también campos completos.
- Valida horas de 24 h, medianoche, superposiciones, códigos y equipo del catálogo.
- Solo Crear registro guarda toda la hoja en una transacción y cierra la vista
  previa. La operación queda activa para el cierre habitual de la app.
- Cancelar no guarda. Se rechazan duplicados de equipo, fecha y turno.
- La foto queda en memoria durante la vista previa, sin guardarse como adjunto.
- Ayudante y auditoría quedan localmente en condiciones_equipo.reporte_foto;
  no se cambia el contrato de exportación de nube.

La precisión manuscrita y la cámara deben probarse en hardware con Gemini real.
La capa gratuita tiene cuotas y condiciones de datos; consultar
https://ai.google.dev/gemini-api/docs/pricing .

## Pruebas

En el backend:

```powershell
node --test test/talLargoPhoto.test.js
```

En la app:

```powershell
flutter test test/tal_largo_photo_test.dart
```

Los antiguos server.mjs, .env.example y server.test.mjs de esta carpeta son
el prototipo separado anterior. **No se requieren para esta integración** y no
deben iniciarse ni configurarse si usas la ruta nueva de tu API existente.