import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/waiver_2026.dart';

/// Builds a single PDF document containing the 2026 waiver text with initials,
/// plus date, full legal name, and signature image.
///
/// [initials] — list of 8 initial strings (one per [initial] in the waiver).
/// [signaturePngBytes] — PNG image bytes of the signature.
/// [signedDate] — date of signature.
/// [fullLegalName] — signer's full legal name.
Future<Uint8List> buildWaiverPdf({
  required List<String> initials,
  required List<int> signaturePngBytes,
  required DateTime signedDate,
  required String fullLegalName,
}) async {
  final pdf = pw.Document();
  final dateStr =
      '${signedDate.year}-${signedDate.month.toString().padLeft(2, '0')}-${signedDate.day.toString().padLeft(2, '0')}';

  // Build full body text with initials in place
  final buffer = StringBuffer();
  var initialIndex = 0;
  for (final segment in waiver2026Segments) {
    buffer.writeln(segment.text);
    if (segment.needsInitial && initialIndex < initials.length) {
      buffer.writeln('[${initials[initialIndex].trim().isEmpty ? "___" : initials[initialIndex]}]');
      initialIndex++;
    }
  }

  final fullText = buffer.toString();

  // Split into chunks that fit on one page (~1200 chars at line breaks).
  // A single huge Text widget exceeds page height; multiple small widgets let MultiPage paginate.
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
