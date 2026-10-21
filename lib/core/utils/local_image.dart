/// Acceso a imágenes locales (archivos del dispositivo) compatible con web.
///
/// En móvil (`dart:io`) se puede leer el archivo del sistema de archivos; en
/// web no existe un sistema de archivos local, por lo que la implementación
/// devuelve `null` y la interfaz usa la URL pública de Supabase Storage o las
/// iniciales del usuario como avatar.
library;

export 'local_image_stub.dart'
    if (dart.library.io) 'local_image_io.dart'
    if (dart.library.js_interop) 'local_image_web.dart';
