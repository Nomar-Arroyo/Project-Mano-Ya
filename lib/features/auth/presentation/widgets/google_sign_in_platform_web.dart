import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart';

/// Botón oficial de Google Identity Services para la web.
///
/// La API de Google en el navegador **no permite** iniciar sesión con un
/// botón hecho por la aplicación: hay que usar el que dibuja el propio SDK.
Widget buildWebGoogleButton() {
  return SizedBox(
    height: 44,
    child: renderButton(
      configuration: GSIButtonConfiguration(
        type: GSIButtonType.standard,
        size: GSIButtonSize.large,
        theme: GSIButtonTheme.outline,
        shape: GSIButtonShape.pill,
        text: GSIButtonText.signinWith,
        locale: 'es',
      ),
    ),
  );
}
