import 'dart:io';

import 'package:flutter/widgets.dart';

/// Construye el proveedor de imagen a partir de un archivo local.
///
/// Devuelve `null` cuando la ruta está vacía o el archivo ya no existe en el
/// dispositivo, para que la interfaz muestre el avatar de respaldo.
ImageProvider? localImageProvider(String path) {
  if (path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return FileImage(file);
}

/// En móvil los archivos locales están disponibles.
bool get supportsLocalFiles => true;
