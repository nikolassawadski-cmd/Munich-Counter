import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/trip_repository.dart';
import '../models/settings.dart';
import '../models/trip.dart';
import '../services/export_service.dart';
import '../services/file_access.dart';
import '../services/haptics.dart';
import '../services/tax_summary.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.repository});

  final TripRepository repository;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _year = DateTime.now().year;
  bool _busy = false;

  TripRepository get _repo => widget.repository;

  List<Trip> get _monthTrips => _repo.tripsInMonth(_month.year, _month.month);

  YearSummary get _yearSummary => summarizeYear(
        trips: _repo.trips,
        settings: _repo.settings,
        dTickets: _repo.dTickets,
        year: _year,
      );

  Future<PdfFonts> _fonts() async => PdfFonts(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );

  // Sharing runs straight from the tap handler: Safari only opens the share
  // sheet during a user gesture, so nothing slow may happen before it.
  void _exportMonthCsv() => _share(
        buildCsv(_monthTrips, _repo.settings),
        exportFileName(_month.year, _month.month, 'csv'),
        'text/csv',
      );

  void _exportYearCsv() => _share(
        buildYearCsv(_repo.tripsInYear(_year), _yearSummary, _repo.settings),
        yearExportFileName(_year, 'csv'),
        'text/csv',
      );

  Future<void> _exportMonthPdf() => _buildPdfThenShare(
        exportFileName(_month.year, _month.month, 'pdf'),
        (fonts) => buildPdf(
          trips: _monthTrips,
          year: _month.year,
          month: _month.month,
          settings: _repo.settings,
          dTicket: _repo.dTicket(_month.year, _month.month),
          fonts: fonts,
        ),
      );

  Future<void> _exportYearPdf() => _buildPdfThenShare(
        yearExportFileName(_year, 'pdf'),
        (fonts) => buildYearPdf(
          trips: _repo.tripsInYear(_year),
          summary: _yearSummary,
          settings: _repo.settings,
          dTickets: _repo.dTickets.where((d) => d.year == _year).toList()
            ..sort((a, b) => a.month.compareTo(b.month)),
          fonts: fonts,
        ),
      );

  // PDF generation is async and would lose the gesture, so build it first
  // and let the user share it with a second tap.
  Future<void> _buildPdfThenShare(
      String fileName, Future<Uint8List> Function(PdfFonts) build) async {
    setState(() => _busy = true);
    try {
      final bytes = await build(await _fonts());
      if (!mounted) return;
      await _showReadySheet(bytes, fileName, 'application/pdf');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _exportBackup() {
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    _share(
      Uint8List.fromList(utf8.encode(_repo.exportBackup())),
      'MunichCounter_Sicherung_$stamp.json',
      'application/json',
    );
  }

  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final content = await pickTextFile(accept: '.json,application/json');
      if (content == null) return;
      final count = await _repo.importBackup(content);
      messenger.showSnackBar(
          SnackBar(content: Text('$count Fahrten aus der Sicherung übernommen')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is FormatException
            ? e.message
            : 'Sicherung konnte nicht gelesen werden.'),
      ));
    }
  }

  Future<void> _editDTicket() async {
    final existing = _repo.dTicket(_month.year, _month.month);
    final result = await showDialog<_DTicketResult>(
      context: context,
      builder: (_) => _DTicketDialog(
        month: _month,
        existing: existing,
        defaultPrice: _repo.settings.dTicketPrice,
      ),
    );
    if (result == null) return;
    if (result.ticket == null) {
      await _repo.removeDTicket(_month.year, _month.month);
    } else {
      await _repo.setDTicket(result.ticket!);
    }
  }

  void _share(Uint8List bytes, String fileName, String mimeType) {
    shareOrDownload(bytes, fileName, mimeType).catchError((Object _) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datei konnte nicht geteilt werden.')));
    });
  }

  Future<void> _showReadySheet(
      Uint8List bytes, String fileName, String mimeType) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.picture_as_pdf, size: 48),
              const SizedBox(height: 12),
              Text('$fileName ist bereit',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  _share(bytes, fileName, mimeType);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.ios_share),
                label: const Text('Teilen / Sichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportButtons({
    required VoidCallback onCsv,
    required VoidCallback onPdf,
  }) =>
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: _busy ? null : onCsv,
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('CSV'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _busy ? null : onPdf,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export & Sicherung'),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => SettingsScreen.open(context, _repo),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final trips = _monthTrips;
          final settings = _repo.settings;
          final dTicket = _repo.dTicket(_month.year, _month.month);
          final monthCosts = trips
                  .where((t) => t.studyRelated)
                  .fold(0.0, (s, t) => s + tripCost(t, settings)) +
              (dTicket?.amount ?? 0);
          final year = _yearSummary.total;
          final profileMissing = settings.name.isEmpty ||
              settings.university.isEmpty ||
              settings.studyLocation == null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Monatsexport', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      MonthSwitcher(
                        month: _month,
                        onChanged: (m) => setState(() => _month = m),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatChip(
                            value: '${trips.length}',
                            label: 'Fahrten',
                            color: Destination.muenchen.color,
                          ),
                          const SizedBox(width: 8),
                          StatChip(
                            value:
                                '${trips.where((t) => t.studyRelated).length}',
                            label: 'studienbedingt',
                            color: Destination.heilbronn.color,
                          ),
                          const SizedBox(width: 8),
                          StatChip(
                            value: euroFormat.format(monthCosts),
                            label: 'Kosten Studium',
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.confirmation_number_outlined),
                        title: const Text('Deutschlandticket'),
                        subtitle: Text(dTicket == null
                            ? 'In diesem Monat nicht erfasst'
                            : '${euroFormat.format(dTicket.price)} × '
                                '${dTicket.sharePercent} % = '
                                '${euroFormat.format(dTicket.amount)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _editDTicket,
                      ),
                      const SizedBox(height: 4),
                      _exportButtons(
                          onCsv: _exportMonthCsv, onPdf: _exportMonthPdf),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('Jahresbericht für die Steuer',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      YearSwitcher(
                        year: _year,
                        onChanged: (y) => setState(() => _year = y),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatChip(
                            value: '${year.studyTrips}',
                            label: 'Fahrten Studium',
                            color: Destination.muenchen.color,
                          ),
                          const SizedBox(width: 8),
                          StatChip(
                            value: year.daysAtStudyLocation?.toString() ?? '–',
                            label: 'Tage am Studienort',
                            color: Destination.heilbronn.color,
                          ),
                          const SizedBox(width: 8),
                          StatChip(
                            value: euroFormat.format(year.total),
                            label: 'Fahrtkosten',
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                      if (profileMissing) ...[
                        const SizedBox(height: 8),
                        Material(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text(
                                'Name, Hochschule und Studienort ergänzen'),
                            subtitle:
                                const Text('Erscheinen im Kopf des Berichts'),
                            onTap: () => SettingsScreen.open(context, _repo),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _exportButtons(
                          onCsv: _exportYearCsv, onPdf: _exportYearPdf),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Der Bericht enthält nur studienbedingte Fahrten, eine '
                'Monatsübersicht und die Summen für die Anlage N. Er ersetzt '
                'keine Steuerberatung.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              Text('Datensicherung', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('Sicherung exportieren'),
                      subtitle: Text(
                          '${_repo.trips.length} Fahrten und Einstellungen als JSON-Datei'),
                      onTap: _exportBackup,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Sicherung importieren'),
                      subtitle: const Text(
                          'Fahrten aus einer Sicherungsdatei übernehmen'),
                      onTap: _importBackup,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Alle Daten liegen nur auf diesem Gerät. Exportiere ab und zu '
                'eine Sicherung, z. B. vor einem Handywechsel.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DTicketResult {
  const _DTicketResult(this.ticket);

  /// Null = remove the ticket for this month.
  final DTicketMonth? ticket;
}

class _DTicketDialog extends StatefulWidget {
  const _DTicketDialog({
    required this.month,
    required this.existing,
    required this.defaultPrice,
  });

  final DateTime month;
  final DTicketMonth? existing;
  final double defaultPrice;

  @override
  State<_DTicketDialog> createState() => _DTicketDialogState();
}

class _DTicketDialogState extends State<_DTicketDialog> {
  late bool _active = widget.existing != null;
  late final _price = TextEditingController(
      text: (widget.existing?.price ?? widget.defaultPrice)
          .toStringAsFixed(2)
          .replaceAll('.', ','));
  late double _share = (widget.existing?.sharePercent ?? 100).toDouble();
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_active) {
      Navigator.pop(context, const _DTicketResult(null));
      return;
    }
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (price == null || price < 0) {
      setState(() => _error = 'Bitte einen Betrag eingeben');
      return;
    }
    hapticTick();
    Navigator.pop(
      context,
      _DTicketResult(DTicketMonth(
        year: widget.month.year,
        month: widget.month.month,
        price: price,
        sharePercent: _share.round(),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price =
        double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;
    return AlertDialog(
      title: Text('Deutschlandticket ${monthFormat.format(widget.month)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ticket in diesem Monat'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          if (_active) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monatspreis',
                suffixText: '€',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Anteil Studium: ${_share.round()} %'),
            ),
            Slider(
              value: _share,
              max: 100,
              divisions: 20,
              label: '${_share.round()} %',
              onChanged: (v) => setState(() => _share = v),
            ),
            Text(
              'Absetzbar: ${euroFormat.format(price * _share.round() / 100)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Übernehmen')),
      ],
    );
  }
}
