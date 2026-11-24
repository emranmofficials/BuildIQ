import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:engine/engine.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/logger.dart';

class ReportResult {
  final File file;
  final String message;
  const ReportResult(this.file, this.message);
}

class ReportService {
  /// Exports BOQ lines to CSV with a header row and proper escaping.
  Future<ReportResult> exportCsv({
    required String projectName,
    required BoqSummary summary,
  }) async {
    final rows = <List<dynamic>>[
      ['Description', 'Quantity', 'Unit', 'Rate', 'Amount', 'Category'],
      ...summary.lines.map(
        (line) => [
          line.description,
          line.quantity,
          line.unit,
          line.rateMinor / 100,
          line.amountMinor / 100,
          line.category,
        ],
      ),
      ['TOTAL', '', '', '', summary.totalMinor / 100, ''],
    ];
    final encoded = Csv().encode(rows);
    final file = await _write(
      'boq_${_slug(projectName)}_${_stamp()}.csv',
      encoded,
    );
    return ReportResult(file, 'CSV exported');
  }

  /// Exports BOQ lines to a real .xlsx workbook with a total row.
  Future<ReportResult> exportExcel({
    required String projectName,
    required BoqSummary summary,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['BOQ'];
    excel.setDefaultSheet('BOQ');
    sheet.appendRow([
      TextCellValue('Description'),
      TextCellValue('Quantity'),
      TextCellValue('Unit'),
      TextCellValue('Rate'),
      TextCellValue('Amount'),
      TextCellValue('Category'),
    ]);
    for (final line in summary.lines) {
      sheet.appendRow([
        TextCellValue(line.description),
        DoubleCellValue(line.quantity),
        TextCellValue(line.unit),
        DoubleCellValue(line.rateMinor / 100),
        DoubleCellValue(line.amountMinor / 100),
        TextCellValue(line.category),
      ]);
    }
    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(summary.totalMinor / 100),
      TextCellValue(''),
    ]);
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Failed to encode Excel workbook');
    final file = await _writeBytes(
      'boq_${_slug(projectName)}_${_stamp()}.xlsx',
      bytes,
    );
    return ReportResult(file, 'Excel exported');
  }

  /// Exports BOQ lines to a printable PDF document.
  Future<ReportResult> exportPdf({
    required String projectName,
    required BoqSummary summary,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Bill of Quantities — $projectName',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Qty', 'Unit', 'Rate', 'Amount'],
            data: summary.lines
                .map(
                  (line) => [
                    line.description,
                    _fmt(line.quantity),
                    line.unit,
                    _fmt(line.rateMinor / 100),
                    _fmt(line.amountMinor / 100),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'TOTAL: ${_fmt(summary.totalMinor / 100)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Estimation only — requires qualified structural engineer review.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    final file = await _writeBytes(
      'boq_${_slug(projectName)}_${_stamp()}.pdf',
      bytes,
    );
    await Printing.sharePdf(bytes: bytes, filename: p.basename(file.path));
    return ReportResult(file, 'PDF exported');
  }

  Future<File> _write(String name, String content) async {
    final dir = await _reportsDir();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(content);
    AppLogger.info('Report written: ${file.path}');
    return file;
  }

  Future<File> _writeBytes(String name, List<int> bytes) async {
    final dir = await _reportsDir();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    AppLogger.info('Report written: ${file.path}');
    return file;
  }

  Future<Directory> _reportsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'reports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _slug(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  String _stamp() => DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[-:.T]'), '')
      .substring(0, 14);

  String _fmt(double value) => value.toStringAsFixed(2);
}
