import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/settings.dart';
import '../models/trip.dart';
import 'tax_summary.dart';

final _date = DateFormat('dd.MM.yyyy', 'de_DE');
final _shortDate = DateFormat('EE, dd.MM.yyyy', 'de_DE');
final _time = DateFormat('HH:mm', 'de_DE');
final _weekday = DateFormat('EEEE', 'de_DE');
final _monthTitle = DateFormat('MMMM yyyy', 'de_DE');
final _monthName = DateFormat('MMMM', 'de_DE');
final _plainNumber = NumberFormat('0.00', 'de_DE');

String exportFileName(int year, int month, String extension) =>
    'Fahrten_$year-${month.toString().padLeft(2, '0')}.$extension';

String yearExportFileName(int year, String extension) =>
    'Fahrtkosten_Steuerjahr_$year.$extension';

// The bundled Roboto has no "→" glyph.
String _route(Trip t) => '${t.origin.label} » ${t.destination.label}';
String _yesNo(bool v) => v ? 'Ja' : 'Nein';
String _distance(Trip t) =>
    t.transport == Transport.auto && t.distanceKm != null
        ? kmFormat.format(t.distanceKm)
        : '';

// ---------------------------------------------------------------- CSV ----

/// CSV in German Excel conventions: `;` separator, decimal comma, UTF-8 with
/// BOM so umlauts show correctly in Excel.
Uint8List buildCsv(List<Trip> trips, AppSettings settings) =>
    _encodeCsv(_tripRows(trips, settings));

/// All trips of the year followed by the summary block.
Uint8List buildYearCsv(
    List<Trip> trips, YearSummary summary, AppSettings settings) {
  final s = summary.total;
  return _encodeCsv([
    ..._tripRows(trips, settings),
    [],
    ['Zusammenfassung Steuerjahr ${summary.year} (nur studienbedingt)'],
    ['Studienbedingte Fahrten', '${s.studyTrips}'],
    ['Private Fahrten (nicht berücksichtigt)', '${s.privateTrips}'],
    if (s.daysAtStudyLocation != null)
      [
        'Tage am Studienort (${settings.studyLocation!.label})',
        '${s.daysAtStudyLocation}',
      ],
    ['Einzeltickets (EUR)', _plainNumber.format(s.ticketCosts)],
    ['Deutschlandticket anteilig (EUR)', _plainNumber.format(s.dTicketCosts)],
    ['Pkw-Kilometer', _plainNumber.format(s.carKm)],
    ['Pkw-Kosten (EUR)', _plainNumber.format(s.carCosts)],
    ['Summe Fahrtkosten (EUR)', _plainNumber.format(s.total)],
  ]);
}

List<List<String>> _tripRows(List<Trip> trips, AppSettings settings) => [
      const [
        'Datum',
        'Wochentag',
        'Uhrzeit',
        'Von',
        'Nach',
        'Anlass',
        'Studienbedingt',
        'Verkehrsmittel',
        'ICE-Ticket',
        'Km (Pkw)',
        'Kosten (EUR)',
        'Notiz',
      ],
      for (final t in trips)
        [
          _date.format(t.departure),
          _weekday.format(t.departure),
          _time.format(t.departure),
          t.origin.label,
          t.destination.label,
          t.purpose?.label ?? '',
          _yesNo(t.studyRelated),
          t.transport.label,
          _yesNo(t.iceTicket),
          _distance(t),
          _plainNumber.format(tripCost(t, settings)),
          t.note,
        ],
    ];

Uint8List _encodeCsv(List<List<String>> rows) {
  final csv = rows.map((r) => r.map(_csvField).join(';')).join('\r\n');
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$csv\r\n')]);
}

String _csvField(String value) {
  if (value.contains(RegExp(r'[;"\r\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

// ---------------------------------------------------------------- PDF ----

class PdfFonts {
  const PdfFonts(this.regular, this.bold);
  final ByteData regular;
  final ByteData bold;
}

Future<Uint8List> buildPdf({
  required List<Trip> trips,
  required int year,
  required int month,
  required AppSettings settings,
  required DTicketMonth? dTicket,
  required PdfFonts fonts,
}) {
  final title = _monthTitle.format(DateTime(year, month));
  final study = trips.where((t) => t.studyRelated);
  final studyCosts = study.fold(0.0, (s, t) => s + tripCost(t, settings)) +
      (dTicket?.amount ?? 0);

  final doc = pw.Document(title: 'Fahrten $title');
  doc.addPage(_page(
    fonts: fonts,
    title: 'Fahrtenübersicht $title',
    subtitle: _profileLine(settings),
    build: (_) => [
      pw.Row(children: [
        _summaryBox('Fahrten gesamt', '${trips.length}'),
        pw.SizedBox(width: 8),
        _summaryBox('davon studienbedingt', '${study.length}'),
        pw.SizedBox(width: 8),
        _summaryBox('mit ICE-Ticket', '${trips.where((t) => t.iceTicket).length}'),
        pw.SizedBox(width: 8),
        _summaryBox('Kosten (studienbedingt)', euroFormat.format(studyCosts)),
      ]),
      pw.SizedBox(height: 16),
      if (trips.isEmpty)
        pw.Text('In diesem Monat wurden keine Fahrten erfasst.')
      else
        _tripTable(trips, settings, withStudyColumn: true),
      if (dTicket != null) ...[
        pw.SizedBox(height: 12),
        pw.Text(_dTicketLine(dTicket)),
      ],
    ],
  ));
  return doc.save();
}

Future<Uint8List> buildYearPdf({
  required List<Trip> trips,
  required YearSummary summary,
  required AppSettings settings,
  required List<DTicketMonth> dTickets,
  required PdfFonts fonts,
}) {
  final s = summary.total;
  final studyTrips = trips.where((t) => t.studyRelated).toList();
  final year = summary.year;

  final doc = pw.Document(title: 'Fahrtkosten Steuerjahr $year');
  doc.addPage(_page(
    fonts: fonts,
    title: 'Fahrtkosten Masterstudium – Steuerjahr $year',
    subtitle: _profileLine(settings),
    build: (_) => [
      _heading('Werte für die Anlage N'),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          border: pw.Border.all(color: PdfColors.blue200),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _keyValue('Fahrtkosten öffentliche Verkehrsmittel',
                euroFormat.format(s.publicTransportCosts)),
            _keyValue(
              'Fahrtkosten Pkw (${kmFormat.format(s.carKm)} km × '
              '${euroFormat.format(settings.kmRate)})',
              euroFormat.format(s.carCosts),
            ),
            pw.Divider(color: PdfColors.blue200),
            _keyValue('Summe Fahrtkosten Studium', euroFormat.format(s.total),
                bold: true),
            pw.SizedBox(height: 8),
            pw.Text(
              'Als Werbungskosten in der Anlage N eintragen, je nach '
              'Studienmodell als Fortbildungskosten bzw. Reisekosten unter '
              '„Weitere Werbungskosten“. Die genaue Zeile hängt vom '
              'Formularjahr ab. Diese Aufstellung ist keine Steuerberatung.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      _heading('Zusammenfassung (nur studienbedingte Fahrten)'),
      _keyValue('Studienbedingte Fahrten', '${s.studyTrips}'),
      _keyValue('Private Fahrten (nicht berücksichtigt)', '${s.privateTrips}'),
      _keyValue(
        settings.studyLocation == null
            ? 'Tage am Studienort'
            : 'Tage am Studienort (${settings.studyLocation!.label})',
        s.daysAtStudyLocation?.toString() ?? 'Studienort nicht festgelegt',
      ),
      _keyValue('Einzeltickets', euroFormat.format(s.ticketCosts)),
      _keyValue('Deutschlandticket (anteilig)', euroFormat.format(s.dTicketCosts)),
      _keyValue('Pkw-Kilometer', '${kmFormat.format(s.carKm)} km'),
      pw.SizedBox(height: 16),
      _heading('Monatsübersicht'),
      _monthTable(summary),
      pw.SizedBox(height: 16),
      _heading('Einzelaufstellung studienbedingter Fahrten'),
      if (studyTrips.isEmpty)
        pw.Text('Keine studienbedingten Fahrten erfasst.')
      else
        _tripTable(studyTrips, settings, withStudyColumn: false),
      if (dTickets.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        _heading('Deutschlandticket'),
        for (final d in dTickets) pw.Text(_dTicketLine(d)),
      ],
    ],
  ));
  return doc.save();
}

pw.MultiPage _page({
  required PdfFonts fonts,
  required String title,
  required String subtitle,
  required List<pw.Widget> Function(pw.Context) build,
}) =>
    pw.MultiPage(
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(fonts.regular),
        bold: pw.Font.ttf(fonts.bold),
      ),
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            [
              if (subtitle.isNotEmpty) subtitle,
              'Erstellt am ${_date.format(DateTime.now())}',
            ].join('   ·   '),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Seite ${context.pageNumber} von ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: build,
    );

String _profileLine(AppSettings s) => [
      if (s.name.isNotEmpty) s.name,
      if (s.university.isNotEmpty) s.university,
      if (s.program.isNotEmpty) s.program,
    ].join(' · ');

String _dTicketLine(DTicketMonth d) =>
    'Deutschlandticket ${_monthTitle.format(DateTime(d.year, d.month))}: '
    '${euroFormat.format(d.price)} × ${d.sharePercent} % Studienanteil = '
    '${euroFormat.format(d.amount)}';

pw.Widget _heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _keyValue(String key, String value, {bool bold = false}) {
  final style = pw.TextStyle(
      fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(children: [
      pw.SizedBox(width: 300, child: pw.Text(key, style: style)),
      pw.Text(value, style: style),
    ]),
  );
}

pw.Widget _tripTable(List<Trip> trips, AppSettings settings,
        {required bool withStudyColumn}) =>
    _table(
      headers: [
        'Datum',
        'Uhrzeit',
        'Strecke',
        'Anlass',
        if (withStudyColumn) 'Studium',
        'Verkehrsmittel',
        'ICE-Ticket',
        'Km',
        'Kosten',
        'Notiz',
      ],
      rows: [
        for (final t in trips)
          [
            _shortDate.format(t.departure),
            _time.format(t.departure),
            _route(t),
            t.purpose?.label ?? '–',
            if (withStudyColumn) _yesNo(t.studyRelated),
            t.transport.label,
            _yesNo(t.iceTicket),
            _distance(t),
            euroFormat.format(tripCost(t, settings)),
            t.note,
          ],
      ],
      rightAligned: {withStudyColumn ? 7 : 6, withStudyColumn ? 8 : 7},
    );

pw.Widget _monthTable(YearSummary summary) {
  final rows = <List<String>>[];
  for (var i = 0; i < 12; i++) {
    final m = summary.months[i];
    rows.add([
      _monthName.format(DateTime(summary.year, i + 1)),
      '${m.studyTrips}',
      m.daysAtStudyLocation?.toString() ?? '–',
      euroFormat.format(m.ticketCosts),
      euroFormat.format(m.dTicketCosts),
      kmFormat.format(m.carKm),
      euroFormat.format(m.carCosts),
      euroFormat.format(m.total),
    ]);
  }
  final t = summary.total;
  rows.add([
    'Summe',
    '${t.studyTrips}',
    t.daysAtStudyLocation?.toString() ?? '–',
    euroFormat.format(t.ticketCosts),
    euroFormat.format(t.dTicketCosts),
    kmFormat.format(t.carKm),
    euroFormat.format(t.carCosts),
    euroFormat.format(t.total),
  ]);
  return _table(
    headers: const [
      'Monat',
      'Fahrten',
      'Tage Studienort',
      'Einzeltickets',
      'D-Ticket',
      'Pkw-km',
      'Pkw-Kosten',
      'Summe',
    ],
    rows: rows,
    rightAligned: {1, 2, 3, 4, 5, 6, 7},
    boldLastRow: true,
    columnWidths: {
      for (var i = 0; i < 8; i++) i: pw.FlexColumnWidth(i == 0 ? 1.4 : 1),
    },
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
  Set<int> rightAligned = const {},
  bool boldLastRow = false,
  Map<int, pw.TableColumnWidth>? columnWidths,
}) =>
    pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: columnWidths,
      headerStyle: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
      textStyleBuilder: boldLastRow
          ? (index, data, row) => row == rows.length
              ? pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)
              : null
          : null,
    );

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
                    pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
