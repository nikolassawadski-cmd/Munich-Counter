import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/trip.dart';

final _date = DateFormat('dd.MM.yyyy', 'de_DE');
final _time = DateFormat('HH:mm', 'de_DE');
final _weekday = DateFormat('EEEE', 'de_DE');
final _monthTitle = DateFormat('MMMM yyyy', 'de_DE');

String exportFileName(int year, int month, String extension) =>
    'Fahrten_$year-${month.toString().padLeft(2, '0')}.$extension';

/// CSV in German Excel conventions: `;` separator, UTF-8 with BOM so umlauts
/// show correctly when opened in Excel.
Uint8List buildCsv(List<Trip> trips) {
  const header = [
    'Datum',
    'Wochentag',
    'Uhrzeit',
    'Ziel',
    'Verkehrsmittel',
    'ICE-Ticket',
    'Notiz',
  ];
  final rows = [
    header,
    for (final t in trips)
      [
        _date.format(t.departure),
        _weekday.format(t.departure),
        _time.format(t.departure),
        t.destination.label,
        t.transport.label,
        t.iceTicket ? 'Ja' : 'Nein',
        t.note,
      ],
  ];
  final csv = rows.map((r) => r.map(_csvField).join(';')).join('\r\n');
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$csv\r\n')]);
}

String _csvField(String value) {
  if (value.contains(RegExp(r'[;"\r\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

Future<Uint8List> buildPdf({
  required List<Trip> trips,
  required int year,
  required int month,
  required ByteData regularFont,
  required ByteData boldFont,
}) {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(regularFont),
    bold: pw.Font.ttf(boldFont),
  );
  final title = _monthTitle.format(DateTime(year, month));
  int count(Destination d) => trips.where((t) => t.destination == d).length;
  final withTicket = trips.where((t) => t.iceTicket).length;

  final doc = pw.Document(title: 'Fahrten $title');
  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Fahrtenübersicht $title',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Erstellt am ${_date.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Seite ${context.pageNumber} von ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (_) => [
        pw.Row(children: [
          _summaryBox('Fahrten gesamt', '${trips.length}'),
          pw.SizedBox(width: 8),
          for (final d in Destination.values) ...[
            _summaryBox('nach ${d.label}', '${count(d)}'),
            pw.SizedBox(width: 8),
          ],
          _summaryBox('mit ICE-Ticket', '$withTicket'),
        ]),
        pw.SizedBox(height: 20),
        if (trips.isEmpty)
          pw.Text('In diesem Monat wurden keine Fahrten erfasst.')
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Datum',
              'Uhrzeit',
              'Ziel',
              'Verkehrsmittel',
              'ICE-Ticket',
              'Notiz',
            ],
            data: [
              for (final t in trips)
                [
                  '${DateFormat('EE', 'de_DE').format(t.departure)}, '
                      '${_date.format(t.departure)}',
                  _time.format(t.departure),
                  t.destination.label,
                  t.transport.label,
                  t.iceTicket ? 'Ja' : 'Nein',
                  t.note,
                ],
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: const {
              0: pw.FixedColumnWidth(78),
              1: pw.FixedColumnWidth(42),
              2: pw.FixedColumnWidth(60),
              3: pw.FixedColumnWidth(70),
              4: pw.FixedColumnWidth(50),
              5: pw.FlexColumnWidth(),
            },
            cellAlignment: pw.Alignment.centerLeft,
          ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _summaryBox(String label, String value) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
