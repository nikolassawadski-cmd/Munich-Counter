import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';

/// Holds all trips in memory and persists them as one JSON list in
/// SharedPreferences (= localStorage on web). There is no backend.
class TripRepository extends ChangeNotifier {
  TripRepository(this._prefs) {
    _load();
  }

  static const _storageKey = 'trips_v1';
  static const backupFormat = 'munich-counter-backup';

  final SharedPreferences _prefs;
  List<Trip> _trips = [];

  /// All trips, newest departure first.
  List<Trip> get trips => List.unmodifiable(_trips);

  /// The destination of the most recent trip that has already started.
  /// Trips entered for a future time do not change the current location.
  Destination? currentLocation([DateTime? now]) {
    final reference = now ?? DateTime.now();
    for (final trip in _trips) {
      if (!trip.departure.isAfter(reference)) return trip.destination;
    }
    return null;
  }

  Trip? get lastTrip => _trips.isEmpty ? null : _trips.first;

  List<Trip> tripsInMonth(int year, int month) => _trips
      .where((t) => t.departure.year == year && t.departure.month == month)
      .toList()
    ..sort((a, b) => a.departure.compareTo(b.departure));

  Future<void> add(Trip trip) async {
    _trips.add(trip);
    await _saveAndNotify();
  }

  Future<void> update(Trip trip) async {
    final index = _trips.indexWhere((t) => t.id == trip.id);
    if (index == -1) return;
    _trips[index] = trip;
    await _saveAndNotify();
  }

  Future<void> delete(String id) async {
    _trips.removeWhere((t) => t.id == id);
    await _saveAndNotify();
  }

  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
        'format': backupFormat,
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'trips': _trips.map((t) => t.toJson()).toList(),
      });

  /// Merges trips from a backup file into the existing data; trips with an
  /// id that already exists are overwritten. Returns the number imported.
  Future<int> importBackup(String content) async {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> || decoded['format'] != backupFormat) {
      throw const FormatException('Keine gültige Munich-Counter-Sicherung.');
    }
    final imported = (decoded['trips'] as List)
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
    final byId = {for (final t in _trips) t.id: t};
    for (final t in imported) {
      byId[t.id] = t;
    }
    _trips = byId.values.toList();
    await _saveAndNotify();
    return imported.length;
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  static int _counter = 0;

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw != null) {
      _trips = (jsonDecode(raw) as List)
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _sort();
  }

  Future<void> _saveAndNotify() async {
    _sort();
    notifyListeners();
    await _prefs.setString(
      _storageKey,
      jsonEncode(_trips.map((t) => t.toJson()).toList()),
    );
  }

  void _sort() => _trips.sort((a, b) => b.departure.compareTo(a.departure));
}
