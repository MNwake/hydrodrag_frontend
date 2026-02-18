import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Strips HTML tags and decodes common entities to plain text.
String stripHtmlToPlainText(String html) {
  if (html.isEmpty) return '';
  String text = html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // Collapse multiple spaces/newlines to single newline where appropriate
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

/// Builds a single PDF document containing the waiver body (from HTML content)
/// plus a final page with date, full legal name, and signature image.
///
/// [htmlContent] — waiver body HTML from config (will be stripped to plain text for PDF).
/// [signaturePngBytes] — PNG image bytes of the signature.
/// [signedDate] — date of signature.
/// [fullLegalName] — signer's full legal name.
Future<Uint8List> buildWaiverPdf({
  required String htmlContent,
  required List<int> signaturePngBytes,
  required DateTime signedDate,
  required String fullLegalName,
}) async {
  final pdf = pw.Document();
  final dateStr =
      '${signedDate.year}-${signedDate.month.toString().padLeft(2, '0')}-${signedDate.day.toString().padLeft(2, '0')}';

  var fullText = stripHtmlToPlainText(htmlContent);
  if (fullText.isEmpty) {
    fullText = 'Waiver content.';
  }
  // Replace [initial], [date], [signature] placeholders so PDF is readable
  fullText = fullText
      .replaceAll(RegExp(r'\[initial\]', caseSensitive: false), '__________')
      .replaceAll(RegExp(r'\[date\]', caseSensitive: false), dateStr)
      .replaceAll(RegExp(r'\[signature\]', caseSensitive: false), '(signed below)');

  // Split into chunks that fit on one page (~1200 chars at line breaks).
  const int charsPerChunk = 1200;
  final List<pw.Widget> textWidgets = [];
  int start = 0;
  while (start < fullText.length) {
    int end = start + charsPerChunk;
    if (end < fullText.length) {
      final atNewline = fullText.lastIndexOf('\n', end);
      final atSpace = fullText.lastIndexOf(' ', end);
      if (atNewline >= start) {
        end = atNewline + 1;
      } else if (atSpace >= start) {
        end = atSpace + 1;
      }
    } else {
      end = fullText.length;
    }
    final chunk = fullText.substring(start, end);
    textWidgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Text(
          chunk,
          style: pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.left,
        ),
      ),
    );
    start = end;
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) => textWidgets,
    ),
  );

  // Final page: date, name, signature image
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 24),
          pw.Text(
            'Date: $dateStr',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            "Competitor/Participant's Legal Signature:",
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            fullLegalName,
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey800),
            ),
            child: pw.Image(
              pw.MemoryImage(Uint8List.fromList(signaturePngBytes)),
              fit: pw.BoxFit.contain,
              width: 300,
              height: 120,
            ),
          ),
        ],
      ),
    ),
  );

  return pdf.save();
}
