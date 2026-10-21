import 'package:flutter/material.dart';

import '../../../core/utils/local_image.dart';

/// Imagen rectangular reutilizable de la aplicación.
///
/// Acepta tres fuentes, en este orden de prioridad:
/// 1. URL pública (`http`/`https`): imágenes subidas a Supabase Storage.
/// 2. Ruta local del dispositivo: válida únicamente en móvil.
/// 3. Marcador de posición: se usa cuando no hay imagen o si la carga falla.
///
/// La resolución web no puede leer archivos del sistema, por eso la lectura de
/// archivos locales se delega a [localImageProvider].
class AppImage extends StatelessWidget {
  /// URL pública o ruta local de la imagen (puede ser nula).
  final String? imageUrl;

  /// Ancho de la imagen.
  final double? width;

  /// Alto de la imagen.
  final double? height;

  /// Ajuste de la imagen dentro del espacio disponible.
  final BoxFit fit;

  /// Icono mostrado cuando no hay imagen disponible.
  final IconData fallbackIcon;

  /// Color de fondo del marcador de posición.
  final Color? fallbackColor;

  const AppImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_not_supported_outlined,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = (imageUrl ?? '').trim();

    final placeholder = Container(
      width: width,
      height: height,
      color: fallbackColor ?? theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: theme.colorScheme.outline),
    );

    if (url.isEmpty) return placeholder;

    // Imagen remota (Supabase Storage u otra URL pública).
    // En web el selector de imágenes entrega URLs "blob:" que el navegador
    // puede cargar directamente.
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('blob:')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    // Imagen local del dispositivo (solo móvil).
    final localProvider = localImageProvider(url);
    if (localProvider == null) return placeholder;

    return Image(
      image: localProvider,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
