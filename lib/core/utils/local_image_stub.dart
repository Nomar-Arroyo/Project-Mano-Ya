import 'package:flutter/widgets.dart';

/// Implementación por defecto para plataformas sin sistema de archivos local.
///
/// No se puede construir un `ImageProvider` a partir de una ruta, por lo que
/// se devuelve `null` y la interfaz cae en el avatar de respaldo.
ImageProvider? localImageProvider(String path) => null;

/// Indica si la plataforma admite imágenes guardadas en el dispositivo.
bool get supportsLocalFiles => false;
