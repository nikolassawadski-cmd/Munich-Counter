import 'package:flutter/material.dart';

import '../data/trip_repository.dart';
import '../models/trip.dart';
import '../services/haptics.dart';
import '../services/tax_summary.dart';
import '../widgets/common.dart';

/// Create (trip == null) or edit a trip.
class TripFormScreen extends StatefulWidget {
  const TripFormScreen({
    super.key,
    required this.repository,
    this.trip,
    this.initialDestination,
    this.initialDate,
  });

  final TripRepository repository;
  final Trip? trip;
  final Destination? initialDestination;
  final DateTime? initialDate;

  static Future<void> open(
    BuildContext context,
    TripRepository repository, {
    Trip? trip,
    Destination? destination,
    DateTime? date,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TripFormScreen(
          repository: repository,
          trip: trip,
          initialDestination: destination,
          initialDate: date,
        ),
      ));

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

/// Parses "29,90", "29.90" or "29" into cents. Empty → null.
int? parseCents(String input) {
  final text = input.trim().replaceAll('€', '').replaceAll(',', '.').trim();
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || value < 0) throw const FormatException();
  return (value * 100).round();
}

class _TripFormScreenState extends State<TripFormScreen> {
  late Destination _destination;
  late DateTime _date;
  late TimeOfDay _time;
  late Transport _transport;
  late bool _iceTicket;
  late Purpose _purpose;
  late bool _studyRelated;
  late final TextEditingController _note;
  late final TextEditingController _price;
  late final TextEditingController _km;
  String? _priceError;
  String? _kmError;

  bool get _isEdit => widget.trip != null;
  bool get _isCar => _transport == Transport.auto;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository;
    final trip = widget.trip;
    // New trips reuse transport, ticket and purpose of the previous trip,
    // since those rarely change between journeys.
    final previous = repo.lastTrip;
    final now = DateTime.now();
    final departure = trip?.departure ??
        (widget.initialDate == null
            ? now
            : DateTime(widget.initialDate!.year, widget.initialDate!.month,
                widget.initialDate!.day, now.hour, now.minute));
    _destination = trip?.destination ??
        widget.initialDestination ??
        (repo.currentLocation()?.other ?? Destination.muenchen);
    _date = DateUtils.dateOnly(departure);
    _time = TimeOfDay.fromDateTime(departure);
    _transport = trip?.transport ?? previous?.transport ?? Transport.ice;
    _iceTicket = trip?.iceTicket ?? previous?.iceTicket ?? true;
    _purpose = trip?.purpose ??
        (previous?.purpose == Purpose.privat ? null : previous?.purpose) ??
        Purpose.vorlesung;
    _studyRelated = trip?.studyRelated ?? _purpose != Purpose.privat;
    _note = TextEditingController(text: trip?.note ?? '');

    final lastPrice = trip == null
        ? repo.trips
            .where((t) => t.destination == _destination && t.priceCents != null)
            .firstOrNull
            ?.priceCents
        : trip.priceCents;
    _price = TextEditingController(
        text: lastPrice == null ? '' : _centsToInput(lastPrice));
    final km = trip?.distanceKm ?? repo.settings.routeKm;
    _km = TextEditingController(text: km == null ? '' : kmFormat.format(km));
  }

  static String _centsToInput(int cents) =>
      (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

  @override
  void dispose() {
    _note.dispose();
    _price.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  double? _parsedKm() {
    final text = _km.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  Future<void> _save() async {
    int? priceCents;
    double? km;
    setState(() => _priceError = _kmError = null);
    if (_isCar) {
      km = _parsedKm();
      if (_km.text.trim().isNotEmpty && (km == null || km < 0)) {
        setState(() => _kmError = 'Bitte eine Zahl eingeben, z. B. 245');
        return;
      }
    } else {
      try {
        priceCents = parseCents(_price.text);
      } on FormatException {
        setState(() => _priceError = 'Bitte einen Betrag eingeben, z. B. 29,90');
        return;
      }
    }

    // Before any await: iOS only allows the haptic during the tap.
    hapticTick();
    final trip = Trip(
      id: widget.trip?.id ?? TripRepository.newId(),
      destination: _destination,
      departure: DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute),
      transport: _transport,
      iceTicket: _iceTicket,
      note: _note.text.trim(),
      purpose: _purpose,
      studyRelated: _studyRelated,
      priceCents: priceCents,
      distanceKm: km,
    );
    if (_isEdit) {
      await widget.repository.update(trip);
    } else {
      await widget.repository.add(trip);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEdit
          ? 'Fahrt aktualisiert'
          : 'Fahrt nach ${_destination.label} gespeichert'),
    ));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fahrt löschen?'),
        content: const Text('Dieser Eintrag wird endgültig entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              hapticTick();
              Navigator.pop(context, true);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.delete(widget.trip!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.repository.settings;
    final km = _parsedKm();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Fahrt bearbeiten' : 'Neue Fahrt'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Ziel', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<Destination>(
              segments: [
                for (final d in Destination.values)
                  ButtonSegment(
                    value: d,
                    label: Text(d.label),
                    icon: Icon(d.icon),
                  ),
              ],
              selected: {_destination},
              onSelectionChanged: (s) => setState(() => _destination = s.first),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Datum'),
                    trailing: Text(dayFormat.format(_date),
                        style: theme.textTheme.bodyLarge),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Abfahrt'),
                    trailing: Text(
                      '${_time.hour.toString().padLeft(2, '0')}:'
                      '${_time.minute.toString().padLeft(2, '0')} Uhr',
                      style: theme.textTheme.bodyLarge,
                    ),
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Anlass', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in Purpose.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(p.icon, size: 18),
                    label: Text(p.label),
                    selected: _purpose == p,
                    // Picking "Privat" (or leaving it) also flips the switch;
                    // it can still be overridden afterwards.
                    onSelected: (_) => setState(() {
                      _purpose = p;
                      _studyRelated = p != Purpose.privat;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                secondary: Icon(
                  _studyRelated ? Icons.school : Icons.school_outlined,
                  color: _studyRelated ? theme.colorScheme.primary : null,
                ),
                title: const Text('Studienbedingt'),
                subtitle: Text(_studyRelated
                    ? 'Zählt für die Steuer'
                    : 'Private Fahrt, zählt nicht für die Steuer'),
                value: _studyRelated,
                onChanged: (v) => setState(() => _studyRelated = v),
              ),
            ),
            const SizedBox(height: 16),
            Text('Verkehrsmittel', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in Transport.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(t.icon, size: 18),
                    label: Text(t.label),
                    selected: _transport == t,
                    onSelected: (_) => setState(() => _transport = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isCar)
              TextField(
                controller: _km,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Gefahrene Kilometer',
                  suffixText: 'km',
                  errorText: _kmError,
                  helperText: km == null
                      ? (settings.routeKm == null
                          ? 'Tipp: Strecke einmal in den Einstellungen speichern'
                          : null)
                      : '= ${euroFormat.format(km * settings.kmRate)} '
                          '(${euroFormat.format(settings.kmRate)} pro km)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              )
            else
              TextField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Ticketpreis',
                  suffixText: '€',
                  hintText: 'z. B. 29,90',
                  errorText: _priceError,
                  helperText:
                      'Leer lassen, wenn die Fahrt mit dem Deutschlandticket war',
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                secondary: Icon(
                  _iceTicket
                      ? Icons.confirmation_number
                      : Icons.confirmation_number_outlined,
                  color: _iceTicket ? Colors.green.shade600 : null,
                ),
                title: const Text('ICE-Ticket vorhanden'),
                subtitle: Text(_iceTicket ? 'Ja' : 'Nein'),
                value: _iceTicket,
                onChanged: (v) => setState(() => _iceTicket = v),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: 'z. B. Modul oder Veranstaltung',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _destination.color,
              ),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'Änderungen speichern' : 'Fahrt speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
