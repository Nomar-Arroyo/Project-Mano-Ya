// jsPDF/PDFKit equivalente en Flutter: pdf
import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static Future<File> generateReceipt({
    required String receiptId,
    required String workerName,
    required String clientName,
    required double amount,
    required String date,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MANO YA - Recibo de Pago',
                style: pw.TextStyle(fontSize: 20),
              ),
              pw.SizedBox(height: 10),
              pw.Text('ID: $receiptId'),
              pw.Text('Cliente: $clientName'),
              pw.Text('Trabajador: $workerName'),
              pw.Text('Monto: \$${amount.toStringAsFixed(2)}'),
              pw.Text('Fecha: $date'),
            ],
          );
        },
      ),
    );
    // dir removed (mock)
    final file = File('recibo_$receiptId.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
