import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<void> openChat({required String phone, String? message}) async {
    final num = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final text = Uri.encodeComponent(message ?? '');
    final uri = Uri.parse('https://wa.me/$num?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
