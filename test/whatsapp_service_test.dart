import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/core/services/whatsapp_service.dart';

void main() {
  group('WhatsAppService.buildChatUrl', () {
    test(
      'convierte el numero local venezolano 0412... en formato internacional',
      () {
        final url = WhatsAppService.buildChatUrl(phone: '0412-111.22.33');

        expect(url, startsWith('https://wa.me/584121112233'));
      },
    );

    test('quita el cero inicial y conserva el prefijo 58', () {
      final url = WhatsAppService.buildChatUrl(phone: '04121112233');

      expect(url, 'https://wa.me/584121112233');
    });

    test('agrega el prefijo 58 a un numero de 10 digitos', () {
      final url = WhatsAppService.buildChatUrl(phone: '4121112233');

      expect(url, 'https://wa.me/584121112233');
    });

    test('respeta un numero que ya viene en formato internacional', () {
      final url = WhatsAppService.buildChatUrl(phone: '584121112233');

      expect(url, 'https://wa.me/584121112233');
    });

    test('codifica el mensaje para que no rompa la URL', () {
      final url = WhatsAppService.buildChatUrl(
        phone: '04121112233',
        message: 'Hola Carlos, ¿estás disponible?',
      );

      expect(url, contains('?text='));
      expect(url, isNot(contains(' ')));
      expect(url, contains('%C2%BFest%C3%A1s'));
    });

    test('devuelve cadena vacia si no hay digitos', () {
      expect(WhatsAppService.buildChatUrl(phone: 'sin numero'), '');
      expect(WhatsAppService.buildChatUrl(phone: ''), '');
    });
  });

  group('WhatsAppService.buildMessage', () {
    test('arma el mensaje de contacto con los datos disponibles', () {
      final message = WhatsAppService.buildMessage(
        workerName: 'Carlos Ramirez',
        category: 'Construccion',
        subcategory: 'Albanil',
        city: 'Caracas',
        clientName: 'Ana',
      );

      expect(message, contains('Carlos Ramirez'));
      expect(message, contains('Construccion'));
      expect(message, contains('Albanil'));
      expect(message, contains('Caracas'));
      expect(message, contains('Ana'));
      expect(message, contains('disponible'));
    });

    test('omite los campos que no se proporcionen', () {
      final message = WhatsAppService.buildMessage(workerName: 'Luis');

      expect(message, contains('Luis'));
      expect(message, isNot(contains('null')));
    });
  });
}
