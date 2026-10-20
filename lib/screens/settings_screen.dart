import 'package:flutter/material.dart';

import '../data/trip_repository.dart';
import '../models/settings.dart';
import '../models/trip.dart';
import '../services/haptics.dart';
import '../services/tax_summary.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final TripRepository repository;

  static Future<void> open(BuildContext context, TripRepository repository) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SettingsScreen(repository: repository)));

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _university;
  late final TextEditingController _program;
  late final TextEditingController _routeKm;
  late final TextEditingController _kmRate;
  late final TextEditingController _dTicketPrice;
  Destination? _studyLocation;
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    final s = widget.repository.settings;
    String number(double? v) => v == null ? '' : _numberFormat(v);
    _name = TextEditingController(text: s.name);
    _university = TextEditingController(text: s.university);
    _program = TextEditingController(text: s.program);
    _routeKm = TextEditingController(text: number(s.routeKm));
    _kmRate = TextEditingController(text: number(s.kmRate));
    _dTicketPrice = TextEditingController(text: number(s.dTicketPrice));
    _studyLocation = s.studyLocation;
  }

  static String _numberFormat(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'.replaceAll('.', ',');

  @override
  void dispose() {
    for (final c in [_name, _university, _program, _routeKm, _kmRate, _dTicketPrice]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String key, TextEditingController c, {bool required = false}) {
    final text = c.text.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      if (required) _errors[key] = 'Pflichtfeld';
      return null;
    }
    final value = double.tryParse(text);
    if (value == null || value < 0) _errors[key] = 'Bitte eine Zahl eingeben';
    return value;
  }

  Future<void> _save() async {
    _errors.clear();
    final routeKm = _parse('routeKm', _routeKm);
    final kmRate = _parse('kmRate', _kmRate, required: true);
    final dTicketPrice = _parse('dTicketPrice', _dTicketPrice, required: true);
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    hapticTick();
    await widget.repository.updateSettings(AppSettings(
      name: _name.text.trim(),
      university: _university.text.trim(),
      program: _program.text.trim(),
      studyLocation: _studyLocation,
      routeKm: routeKm,
      kmRate: kmRate!,
      dTicketPrice: dTicketPrice!,
    ));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    InputDecoration deco(String label, {String? suffix, String? helper, String? key}) =>
        InputDecoration(
          labelText: label,
          suffixText: suffix,
          helperText: helper,
          helperMaxLines: 3,
          errorText: key == null ? null : _errors[key],
          border: const OutlineInputBorder(),
        );
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Für den Jahresbericht', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Erscheint im Kopf des PDF-Berichts.',
                style: theme.textTheme.bodySmall),
            gap,
            TextField(
                controller: _name,
                decoration: deco('Name'),
                textCapitalization: TextCapitalization.words),
            gap,
            TextField(
                controller: _university,
                decoration: deco('Hochschule'),
                textCapitalization: TextCapitalization.words),
            gap,
            TextField(
                controller: _program,
                decoration: deco('Studiengang'),
                textCapitalization: TextCapitalization.words),
            const SizedBox(height: 24),
            Text('Studienort', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Dafür zählt die App die „Tage am Studienort“.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            SegmentedButton<Destination>(
              emptySelectionAllowed: true,
              segments: [
                for (final d in Destination.values)
                  ButtonSegment(value: d, label: Text(d.label)),
              ],
              selected: {if (_studyLocation != null) _studyLocation!},
              onSelectionChanged: (s) =>
                  setState(() => _studyLocation = s.firstOrNull),
            ),
            const SizedBox(height: 24),
            Text('Fahrtkosten', style: theme.textTheme.titleMedium),
            gap,
            TextField(
              controller: _routeKm,
              keyboardType: numberKeyboard,
              decoration: deco('Strecke München – Heilbronn',
                  suffix: 'km',
                  helper: 'Einfache Strecke mit dem Auto. Wird bei Autofahrten '
                      'vorausgefüllt.',
                  key: 'routeKm'),
            ),
            gap,
            TextField(
              controller: _kmRate,
              keyboardType: numberKeyboard,
              decoration: deco('Kilometersatz Auto',
                  suffix: '€/km',
                  helper: 'Üblich sind 0,30 € pro gefahrenem Kilometer. '
                      'Mit Steuerberater abstimmen.',
                  key: 'kmRate'),
            ),
            gap,
            TextField(
              controller: _dTicketPrice,
              keyboardType: numberKeyboard,
              decoration: deco('Deutschlandticket pro Monat',
                  suffix: '€',
                  helper: 'Standardpreis beim Erfassen eines Monats '
                      '(2026: ${euroFormat.format(63)}).',
                  key: 'dTicketPrice'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
