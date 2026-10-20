import 'package:flutter/material.dart';

import '../data/trip_repository.dart';
import '../models/trip.dart';
import '../widgets/common.dart';

/// Create (trip == null) or edit a trip.
class TripFormScreen extends StatefulWidget {
  const TripFormScreen({
    super.key,
    required this.repository,
    this.trip,
    this.initialDestination,
  });

  final TripRepository repository;
  final Trip? trip;
  final Destination? initialDestination;

  static Future<void> open(
    BuildContext context,
    TripRepository repository, {
    Trip? trip,
    Destination? destination,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TripFormScreen(
          repository: repository,
          trip: trip,
          initialDestination: destination,
        ),
      ));

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  late Destination _destination;
  late DateTime _date;
  late TimeOfDay _time;
  late Transport _transport;
  late bool _iceTicket;
  late final TextEditingController _note;

  bool get _isEdit => widget.trip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    // New trips reuse transport/ticket of the previous trip, since those
    // rarely change between journeys.
    final previous = widget.repository.lastTrip;
    final departure = trip?.departure ?? DateTime.now();
    _destination = trip?.destination ??
        widget.initialDestination ??
        _otherThan(widget.repository.currentLocation());
    _date = DateUtils.dateOnly(departure);
    _time = TimeOfDay.fromDateTime(departure);
    _transport = trip?.transport ?? previous?.transport ?? Transport.ice;
    _iceTicket = trip?.iceTicket ?? previous?.iceTicket ?? true;
    _note = TextEditingController(text: trip?.note ?? '');
  }

  static Destination _otherThan(Destination? current) =>
      current == Destination.muenchen
          ? Destination.heilbronn
          : Destination.muenchen;

  @override
  void dispose() {
    _note.dispose();
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

  Future<void> _save() async {
    final departure = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final trip = Trip(
      id: widget.trip?.id ?? TripRepository.newId(),
      destination: _destination,
      departure: departure,
      transport: _transport,
      iceTicket: _iceTicket,
      note: _note.text.trim(),
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
            onPressed: () => Navigator.pop(context, true),
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
            Text('Verkehrsmittel', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in Transport.values)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 18),
                    label: Text(t.label),
                    selected: _transport == t,
                    onSelected: (_) => setState(() => _transport = t),
                  ),
              ],
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
                hintText: 'z. B. Anlass der Reise',
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
