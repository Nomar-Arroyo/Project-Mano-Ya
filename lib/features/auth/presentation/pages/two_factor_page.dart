import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../auth_provider.dart';
import '../../domain/mfa_enrollment.dart';

// Verificación en dos pasos (2FA) con TOTP.
// Cuando la cuenta ya tiene un factor registrado solo se pide el código.
// Cuando el factor esta pendiente de confirmar se muestra el QR y el secreto.
class TwoFactorPage extends ConsumerStatefulWidget {
  const TwoFactorPage({super.key});

  @override
  ConsumerState<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends ConsumerState<TwoFactorPage> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Ingresa los 6 dígitos');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(authStateProvider.notifier)
          .verifyTwoFactor(code);
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok) {
        context.go('/home');
      } else {
        setState(() => _error = 'Código inválido');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _cancel() async {
    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = ref
        .watch(authStateProvider.notifier)
        .pendingMfaEnrollment;
    final isEnrollment = enrollment != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación en 2 pasos'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.verified_user,
                size: 64,
                color: ManoYaColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isEnrollment
                    ? 'Vincula tu aplicación autenticadora'
                    : 'Ingresa el código de 6 dígitos',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEnrollment
                    ? 'Escanea el código QR con Google Authenticator, '
                          'Microsoft Authenticator o Authy y confirma con el '
                          'código de 6 dígitos que generen.'
                    : 'Abre tu aplicación autenticadora e introduce el código '
                          'de 6 dígitos que muestre.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ManoYaColors.muted, fontSize: 13),
              ),
              if (isEnrollment) ...[
                const SizedBox(height: 20),
                _EnrollmentCard(enrollment: enrollment),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Código',
                  counterText: '',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEnrollment ? 'Confirmar y activar' : 'Verificar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Muestra el QR del enrolamiento TOTP y permite copiar el secreto.
class _EnrollmentCard extends StatefulWidget {
  const _EnrollmentCard({required this.enrollment});

  final MfaEnrollment enrollment;

  @override
  State<_EnrollmentCard> createState() => _EnrollmentCardState();
}

class _EnrollmentCardState extends State<_EnrollmentCard> {
  bool _showSecret = false;

  String get _svgSource {
    final raw = widget.enrollment.qrCode;
    final marker = 'base64,';
    final index = raw.indexOf(marker);
    if (index == -1) return '';
    final payload = raw.substring(index + marker.length);
    final decoded = utf8.decode(base64.decode(payload));
    return decoded;
  }

  Future<void> _copySecret() async {
    await Clipboard.setData(ClipboardData(text: widget.enrollment.secret));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Secreto copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svg = _svgSource;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ManoYaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (svg.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ManoYaColors.border),
                ),
                child: SvgPicture.string(svg, height: 190, fit: BoxFit.contain),
              )
            else
              const Icon(
                Icons.qr_code_2,
                size: 120,
                color: ManoYaColors.primary,
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Clave manual',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _showSecret
                        ? widget.enrollment.secret
                        : '•' * widget.enrollment.secret.length,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _showSecret ? 'Ocultar' : 'Mostrar',
                  onPressed: () => setState(() => _showSecret = !_showSecret),
                  icon: Icon(
                    _showSecret ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar',
                  onPressed: _copySecret,
                  icon: const Icon(Icons.copy_all),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
