import 'package:flutter/widgets.dart';

/// En web no existe un sistema de archivos local.
///
/// Las imágenes siempre llegan como URL pública de Supabase Storage, por lo que
/// aquí no se puede construir ningún proveedor de imagen local.
ImageProvider? localImageProvider(String path) => null;

/// En web no se admiten imágenes guardadas en el dispositivo.
bool get supportsLocalFiles => false;
