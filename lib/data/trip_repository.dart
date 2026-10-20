import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';
import '../models/trip.dart';
import '../services/timeline.dart';

/// Holds all app data in memory and persists it as JSON in SharedPreferences
/// (= localStorage on web). There is no backend.
class TripRepository extends ChangeNotifier {
  TripRepository(this._prefs) {
    _load();
  }

  static const _tripsKey = 'trips_v1';
  static const _settingsKey = 'settings_v1';
  static const _dTicketsKey = 'dtickets_v1';
  static const backupFormat = 'munich-counter-backup';

  final SharedPreferences _prefs;
  List<Trip> _trips = [];
  AppSettings _settings = const AppSettings();
  Map<String, DTicketMonth> _dTickets = {};

  /// All trips, newest departure first.
  List<Trip> get trips => List.unmodifiable(_trips);

  AppSettings get settings => _settings;

  Iterable<DTicketMonth> get dTickets => _dTickets.values;

  DTicketMonth? dTicket(int year, int month) =>
      _dTickets[DTicketMonth.keyFor(year, month)];

  /// Trips entered for a future time do not change the current location.
  Destination? currentLocation([DateTime? now]) =>
      locationAt(_trips, now ?? DateTime.now());

  Trip? get lastTrip => _trips.isEmpty ? null : _trips.first;

  List<Trip> tripsInMonth(int year, int month) => _trips
      .where((t) => t.departure.year == year && t.departure.month == month)
      .toList()
    ..sort((a, b) => a.departure.compareTo(b.departure));

  List<Trip> tripsInYear(int year) =>
      _trips.where((t) => t.departure.year == year).toList()
        ..sort((a, b) => a.departure.compareTo(b.departure));

  Future<void> add(Trip trip) async {
    _trips.add(trip);
    await _saveTrips();
  }

  Future<void> update(Trip trip) async {
    final index = _trips.indexWhere((t) => t.id == trip.id);
    if (index == -1) return;
    _trips[index] = trip;
    await _saveTrips();
  }

  Future<void> delete(String id) async {
    _trips.removeWhere((t) => t.id == id);
    await _saveTrips();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> setDTicket(DTicketMonth ticket) async {
    _dTickets[ticket.key] = ticket;
    await _saveDTickets();
  }

  Future<void> removeDTicket(int year, int month) async {
    _dTickets.remove(DTicketMonth.keyFor(year, month));
    await _saveDTickets();
  }

  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
        'format': backupFormat,
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'trips': _trips.map((t) => t.toJson()).toList(),
        'settings': _settings.toJson(),
        'dTickets': _dTickets.values.map((d) => d.toJson()).toList(),
      });

  /// Merges a backup into the existing data: trips and Deutschlandticket
  /// months with the same id/month are overwritten, settings are replaced.
  /// Accepts version 1 backups (trips only). Returns the number of trips.
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

    if (decoded['settings'] case final Map<String, dynamic> s) {
      _settings = AppSettings.fromJson(s);
      await _prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
    }
    if (decoded['dTickets'] case final List<dynamic> list) {
      for (final d in list) {
        final ticket = DTicketMonth.fromJson(d as Map<String, dynamic>);
        _dTickets[ticket.key] = ticket;
      }
      await _saveDTickets();
    }
    await _saveTrips();
    return imported.length;
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  static int _counter = 0;

  void _load() {
    final rawTrips = _prefs.getString(_tripsKey);
    if (rawTrips != null) {
      _trips = (jsonDecode(rawTrips) as List)
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _sort();
    final rawSettings = _prefs.getString(_settingsKey);
    if (rawSettings != null) {
      _settings = AppSettings.fromJson(
          jsonDecode(rawSettings) as Map<String, dynamic>);
    }
    final rawDTickets = _prefs.getString(_dTicketsKey);
    if (rawDTickets != null) {
      final list = (jsonDecode(rawDTickets) as List)
          .map((e) => DTicketMonth.fromJson(e as Map<String, dynamic>));
      _dTickets = {for (final d in list) d.key: d};
    }
  }

  Future<void> _saveTrips() async {
    _sort();
    notifyListeners();
    await _prefs.setString(
      _tripsKey,
      jsonEncode(_trips.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _saveDTickets() async {
    notifyListeners();
    await _prefs.setString(
      _dTicketsKey,
      jsonEncode(_dTickets.values.map((d) => d.toJson()).toList()),
    );
  }

  void _sort() => _trips.sort((a, b) => b.departure.compareTo(a.departure));
}
