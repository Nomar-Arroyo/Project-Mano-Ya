import 'package:flutter/widgets.dart';

/// Versión del botón de Google para las plataformas que no son web.
///
/// En Android e iOS el SDK muestra su propio diálogo, asi que aqui no hay
/// nada que dibujar. Esta versión solo se usa si la app se compila para
/// una plataforma sin navegador.
Widget buildWebGoogleButton() => const SizedBox.shrink();
