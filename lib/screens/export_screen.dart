import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/trip_repository.dart';
import '../models/trip.dart';
import '../services/export_service.dart';
import '../services/file_access.dart';
import '../widgets/common.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.repository});

  final TripRepository repository;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;

  List<Trip> get _trips =>
      widget.repository.tripsInMonth(_month.year, _month.month);

  // Sharing runs straight from the tap handler: Safari only opens the share
  // sheet during a user gesture, so nothing slow may happen before it.
  void _exportCsv() => _share(
        buildCsv(_trips),
        exportFileName(_month.year, _month.month, 'csv'),
        'text/csv',
      );

  // PDF generation is async and would lose the gesture, so build it first
  // and let the user share it with a second tap.
  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await buildPdf(
        trips: _trips,
        year: _month.year,
        month: _month.month,
        regularFont: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
        boldFont: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );
      if (!mounted) return;
      await _showReadySheet(
        bytes,
        exportFileName(_month.year, _month.month, 'pdf'),
        'application/pdf',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _exportBackup() {
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    _share(
      Uint8List.fromList(utf8.encode(widget.repository.exportBackup())),
      'MunichCounter_Sicherung_$stamp.json',
      'application/json',
    );
  }

  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final content = await pickTextFile(accept: '.json,application/json');
      if (content == null) return;
      final count = await widget.repository.importBackup(content);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export & Sicherung')),
      body: ListenableBuilder(
        listenable: widget.repository,
        builder: (context, _) {
          final trips = _trips;
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
                          for (final d in Destination.values) ...[
                            StatChip(
                              value: trips
                                  .where((t) => t.destination == d)
                                  .length,
                              label: 'nach ${d.label}',
                              color: d.color,
                            ),
                            const SizedBox(width: 8),
                          ],
                          StatChip(
                            value: trips.where((t) => t.iceTicket).length,
                            label: 'mit ICE-Ticket',
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48)),
                              onPressed: _busy ? null : _exportCsv,
                              icon: const Icon(Icons.table_chart_outlined),
                              label: const Text('CSV'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48)),
                              onPressed: _busy ? null : _exportPdf,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('PDF'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'CSV öffnet sich in Excel oder Numbers, das PDF ist ein fertiger '
                'Monatsbericht. Beides kannst du per Mail, AirDrop oder in '
                '„Dateien“ sichern.',
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
                          '${widget.repository.trips.length} Fahrten als JSON-Datei'),
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
