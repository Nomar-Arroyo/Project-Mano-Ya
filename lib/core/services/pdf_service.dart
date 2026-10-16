// Generación de recibos en PDF (equivalente a jsPDF/PDFKit en Flutter).
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Servicio de generación de documentos PDF de Mano Ya.
///
/// Crea el Recibo de Pago con el desglose de cuotas/hitos y, cuando el
/// trabajo ya está pagado, estampa el sello visual "TRABAJO PAGADO /
/// GARANTIZADO".
class PdfService {
  /// Genera el recibo de pago y devuelve el archivo creado.
  ///
  /// [installments] es una lista de mapas con las claves `label`, `dueDate`,
  /// `amount` y `status` (texto ya formateado para mostrar).
  static Future<File> generateReceipt({
    required String receiptId,
    required String workerName,
    required String clientName,
    required String concept,
    required double total,
    required double paidAmount,
    required String date,
    required List<Map<String, String>> installments,
    bool sealed = true,
  }) async {
    final pdf = pw.Document();
    final pending = total - paidAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- Encabezado ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'MANO YA',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF2563EB),
                    ),
                  ),
                  pw.Text('Recibo de Pago'),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Text('Recibo N°: $receiptId'),
              pw.Text('Fecha: $date'),

              pw.SizedBox(height: 16),
              // --- Datos generales ---
              pw.Text(
                'Trabajador: $workerName',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Cliente: $clientName'),
              pw.Text('Concepto: $concept'),

              pw.SizedBox(height: 20),
              // --- Tabla de cuotas / hitos ---
              pw.Text(
                'Desglose de cuotas / hitos',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const ['Cuota', 'Vencimiento', 'Monto', 'Estado'],
                data: installments
                    .map(
                      (item) => [
                        item['label'] ?? '',
                        item['dueDate'] ?? '',
                        '\$ ${item['amount'] ?? '0.00'}',
                        item['status'] ?? '',
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE2E8F0),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 16),
              // --- Totales ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total: \$ ${total.toStringAsFixed(2)}'),
                      pw.Text('Pagado: \$ ${paidAmount.toStringAsFixed(2)}'),
                      pw.Text(
                        'Pendiente: \$ ${pending.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 32),
              // --- Sello de trabajo pagado ---
              if (sealed) _seal(),

              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                'Documento generado automáticamente por Mano Ya · '
                'Tus Oficios a la Mano',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          );
        },
      ),
    );

    final dir = Directory.systemTemp;
    final file = File('${dir.path}/recibo_$receiptId.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Construye el sello visual "TRABAJO PAGADO / GARANTIZADO".
  static pw.Widget _seal() {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColor.fromInt(0xFF10B981),
            width: 2.5,
          ),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Text(
          'TRABAJO PAGADO / GARANTIZADO',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF10B981),
          ),
        ),
      ),
    );
  }
}
