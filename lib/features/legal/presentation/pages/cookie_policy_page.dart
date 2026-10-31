import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class CookiePolicyPage extends StatelessWidget {
  const CookiePolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.55);

    return Scaffold(
      appBar: AppBar(title: const Text('Política de cookies')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Política de cookies y almacenamiento web',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Esta política explica qué tecnologías de '
                          'almacenamiento utiliza Mano Ya al navegar en su '
                          'aplicación web y para qué se usan.',
                          style: textStyle,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _PolicySection(
                          title: '1. Tecnologías esenciales',
                          children: [
                            Text(
                              'La aplicación guarda información técnica en el '
                              'almacenamiento local del navegador para '
                              'mantener la sesión iniciada y recordar '
                              'preferencias como el tema y la disponibilidad. '
                              'Este almacenamiento es necesario para prestar '
                              'las funciones solicitadas. No es, estrictamente, '
                              'una cookie HTTP.',
                              style: textStyle,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'La decisión “Aceptar” o “Rechazar” del aviso '
                              'también se recuerda en el almacenamiento local '
                              'para no mostrarlo en cada visita. Esta decisión '
                              'no desactiva el almacenamiento técnico esencial. '
                              'Puedes borrar estos datos desde la configuración '
                              'del navegador; al hacerlo, la aplicación puede '
                              'cerrar tu sesión o volver a mostrar el aviso.',
                              style: textStyle,
                            ),
                          ],
                        ),
                        _PolicySection(
                          title: '2. Inicio de sesión con Google',
                          children: [
                            Text(
                              'Si eliges iniciar sesión con Google, Google '
                              'Identity Services puede utilizar cookies o '
                              'tecnologías similares para autenticarte y '
                              'proteger el inicio de sesión. Su uso se rige '
                              'también por las políticas de privacidad y '
                              'cookies de Google. Si no utilizas esa opción, '
                              'no se inicia ese flujo de autenticación.',
                              style: textStyle,
                            ),
                          ],
                        ),
                        _PolicySection(
                          title: '3. Publicidad y analítica',
                          children: [
                            Text(
                              'La versión actual de Mano Ya no instala cookies '
                              'propias de publicidad, seguimiento entre sitios '
                              'ni analítica. Si esto cambia, actualizaremos esta '
                              'política y, cuando corresponda, solicitaremos '
                              'tu consentimiento antes de activar tecnologías '
                              'no esenciales.',
                              style: textStyle,
                            ),
                          ],
                        ),
                        _PolicySection(
                          title: '4. Cómo administrar el almacenamiento',
                          children: [
                            Text(
                              'Puedes bloquear o borrar cookies y datos de '
                              'sitios desde la configuración de tu navegador. '
                              'Bloquear el almacenamiento esencial puede '
                              'impedir que la sesión se conserve o que algunas '
                              'funciones estén disponibles. También puedes '
                              'cerrar sesión desde la aplicación.',
                              style: textStyle,
                            ),
                          ],
                        ),
                        _PolicySection(
                          title: '5. Cambios y consultas',
                          children: [
                            Text(
                              'Podemos actualizar esta política cuando cambien '
                              'las tecnologías de la aplicación. La versión '
                              'vigente estará disponible desde el aviso de '
                              'cookies de Mano Ya. Para consultas, utiliza los '
                              'canales de soporte disponibles en la aplicación.',
                              style: textStyle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}
