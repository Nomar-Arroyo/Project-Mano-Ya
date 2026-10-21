import 'package:flutter/material.dart';

import '../../../core/utils/local_image.dart';

/// Avatar reutilizable de la aplicación.
///
/// Admite tres fuentes de imagen, en este orden de prioridad:
/// 1. URL pública (http/https): por ejemplo, una imagen subida a Supabase
///    Storage, que funciona igual en móvil y web.
/// 2. Ruta local del dispositivo: válida únicamente en móvil.
/// 3. Iniciales del nombre: avatar de respaldo cuando no hay imagen.
///
/// Si la imagen remota falla al cargar, se muestra automáticamente el avatar
/// de respaldo para no dejar un círculo vacío.
class UserAvatar extends StatelessWidget {
  /// URL pública o ruta local de la imagen (puede ser nula).
  final String? imageUrl;

  /// Nombre del usuario: se usa para construir las iniciales.
  final String? name;

  /// Radio del avatar circular.
  final double radius;

  /// Icono mostrado cuando no hay nombre disponible.
  final IconData fallbackIcon;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 32,
    this.fallbackIcon = Icons.person,
  });

  /// Calcula la inicial (o dos iniciales) a partir del nombre completo.
  String _initials() {
    final fullName = (name ?? '').trim();
    if (fullName.isEmpty) return '';
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Avatar de respaldo con las iniciales del usuario.
  Widget _fallback(Color background, Color foreground) {
    final initials = _initials();
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: initials.isEmpty
          ? Icon(fallbackIcon, size: radius, color: foreground)
          : Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.primaryContainer;
    final foreground = theme.colorScheme.onPrimaryContainer;
    final url = (imageUrl ?? '').trim();

    // Sin imagen: se muestran las iniciales.
    if (url.isEmpty) return _fallback(background, foreground);

    // Imagen remota (Supabase Storage u otra URL pública).
    // En web el selector de imágenes entrega URLs "blob:" que el navegador
    // puede cargar directamente.
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('blob:')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, _) {},
      );
    }

    // Imagen local del dispositivo (solo móvil).
    final localProvider = localImageProvider(url);
    if (localProvider != null) {
      return CircleAvatar(radius: radius, backgroundImage: localProvider);
    }

    return _fallback(background, foreground);
  }
}
