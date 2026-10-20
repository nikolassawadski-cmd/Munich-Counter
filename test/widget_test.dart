import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:munich_counter/data/trip_repository.dart';
import 'package:munich_counter/main.dart';
import 'package:munich_counter/models/trip.dart';
import 'package:munich_counter/services/export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Trip _trip(String id, Destination d, DateTime departure,
        {bool ice = true, String note = ''}) =>
    Trip(
      id: id,
      destination: d,
      departure: departure,
      transport: Transport.ice,
      iceTicket: ice,
      note: note,
    );

Future<TripRepository> _repo([List<Trip> trips = const []]) async {
  SharedPreferences.setMockInitialValues({});
  final repo = TripRepository(await SharedPreferences.getInstance());
  for (final t in trips) {
    await repo.add(t);
  }
  return repo;
}

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  group('TripRepository', () {
    test('current location is the destination of the latest past trip',
        () async {
      final repo = await _repo([
        _trip('1', Destination.heilbronn, DateTime(2026, 10, 1, 8)),
        _trip('2', Destination.muenchen, DateTime(2026, 10, 5, 8)),
        _trip('3', Destination.heilbronn, DateTime(2026, 10, 30, 8)),
      ]);
      expect(repo.currentLocation(DateTime(2026, 10, 10)), Destination.muenchen);
      expect(repo.currentLocation(DateTime(2026, 10, 31)), Destination.heilbronn);
      expect(repo.currentLocation(DateTime(2026, 9, 1)), isNull);
    });

    test('persists trips and restores them', () async {
      final repo =
          await _repo([_trip('1', Destination.muenchen, DateTime(2026, 10, 1))]);
      final reloaded = TripRepository(await SharedPreferences.getInstance());
      expect(reloaded.trips.single.id, repo.trips.single.id);
    });

    test('backup round trip merges by id', () async {
      final source = await _repo([
        _trip('1', Destination.muenchen, DateTime(2026, 10, 1), note: 'neu'),
        _trip('2', Destination.heilbronn, DateTime(2026, 10, 2)),
      ]);
      final backup = source.exportBackup();

      final target =
          await _repo([_trip('1', Destination.muenchen, DateTime(2026, 10, 1))]);
      expect(await target.importBackup(backup), 2);
      expect(target.trips.length, 2);
      expect(target.trips.firstWhere((t) => t.id == '1').note, 'neu');
      expect(() => target.importBackup('{}'), throwsFormatException);
    });
  });

  group('CSV export', () {
    test('uses German Excel format and escapes fields', () {
      final bytes = buildCsv([
        _trip('1', Destination.muenchen, DateTime(2026, 10, 20, 7, 5),
            note: 'Meeting; "wichtig"'),
      ]);
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final lines = utf8.decode(bytes.sublist(3)).trim().split('\r\n');
      expect(lines[0], 'Datum;Wochentag;Uhrzeit;Ziel;Verkehrsmittel;ICE-Ticket;Notiz');
      expect(lines[1],
          '20.10.2026;Dienstag;07:05;München;ICE;Ja;"Meeting; ""wichtig"""');
    });
  });

  testWidgets('home screen shows current location after adding a trip',
      (tester) async {
    final repo = await _repo();
    await tester.pumpWidget(MunichCounterApp(repository: repo));
    expect(find.text('Noch keine Fahrt erfasst'), findsOneWidget);

    await tester.tap(find.text('Fahrt nach Heilbronn'));
    await tester.pumpAndSettle();
    expect(find.text('ICE-Ticket vorhanden'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Nein'), findsOneWidget);

    await tester.ensureVisible(find.text('Fahrt speichern'));
    await tester.tap(find.text('Fahrt speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Sie befinden sich aktuell in'), findsOneWidget);
    expect(repo.trips.single.destination, Destination.heilbronn);
    expect(repo.trips.single.iceTicket, isFalse);
  });

  test('PDF export produces a document', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final pdf = await buildPdf(
      trips: [_trip('1', Destination.muenchen, DateTime(2026, 10, 20))],
      year: 2026,
      month: 10,
      regularFont: font,
      boldFont: font,
    );
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });
}
