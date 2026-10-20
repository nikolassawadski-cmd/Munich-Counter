import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:munich_counter/data/trip_repository.dart';
import 'package:munich_counter/main.dart';
import 'package:munich_counter/models/settings.dart';
import 'package:munich_counter/models/trip.dart';
import 'package:munich_counter/screens/trip_form_screen.dart';
import 'package:munich_counter/services/export_service.dart';
import 'package:munich_counter/services/tax_summary.dart';
import 'package:munich_counter/services/timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

Trip _trip(
  String id,
  Destination d,
  DateTime departure, {
  bool ice = true,
  String note = '',
  Transport transport = Transport.ice,
  bool study = true,
  int? priceCents,
  double? km,
}) =>
    Trip(
      id: id,
      destination: d,
      departure: departure,
      transport: transport,
      iceTicket: ice,
      note: note,
      purpose: study ? Purpose.vorlesung : Purpose.privat,
      studyRelated: study,
      priceCents: priceCents,
      distanceKm: km,
    );

Future<TripRepository> _repo([List<Trip> trips = const []]) async {
  SharedPreferences.setMockInitialValues({});
  final repo = TripRepository(await SharedPreferences.getInstance());
  for (final t in trips) {
    await repo.add(t);
  }
  return repo;
}

Future<PdfFonts> _fonts() async => PdfFonts(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test('persists trips, settings and Deutschlandticket', () async {
      final repo =
          await _repo([_trip('1', Destination.muenchen, DateTime(2026, 10, 1))]);
      await repo.updateSettings(
          const AppSettings(name: 'Test', studyLocation: Destination.muenchen));
      await repo.setDTicket(
          const DTicketMonth(year: 2026, month: 10, price: 63, sharePercent: 50));

      final reloaded = TripRepository(await SharedPreferences.getInstance());
      expect(reloaded.trips.single.id, repo.trips.single.id);
      expect(reloaded.settings.name, 'Test');
      expect(reloaded.settings.studyLocation, Destination.muenchen);
      expect(reloaded.dTicket(2026, 10)!.amount, 31.5);
    });

    test('reads trips stored before costs and purposes existed', () {
      final old = Trip.fromJson({
        'id': 'x',
        'destination': 'heilbronn',
        'departure': '2026-10-01T08:00:00.000',
        'transport': 'ice',
        'iceTicket': true,
        'note': '',
      });
      expect(old.purpose, isNull);
      expect(old.studyRelated, isTrue);
      expect(old.priceCents, isNull);
    });

    test('backup round trip merges by id and restores settings', () async {
      final source = await _repo([
        _trip('1', Destination.muenchen, DateTime(2026, 10, 1), note: 'neu'),
        _trip('2', Destination.heilbronn, DateTime(2026, 10, 2)),
      ]);
      await source.updateSettings(const AppSettings(university: 'TUM'));
      await source.setDTicket(
          const DTicketMonth(year: 2026, month: 10, price: 63));
      final backup = source.exportBackup();

      final target =
          await _repo([_trip('1', Destination.muenchen, DateTime(2026, 10, 1))]);
      expect(await target.importBackup(backup), 2);
      expect(target.trips.length, 2);
      expect(target.trips.firstWhere((t) => t.id == '1').note, 'neu');
      expect(target.settings.university, 'TUM');
      expect(target.dTicket(2026, 10), isNotNull);
      expect(() => target.importBackup('{}'), throwsFormatException);
    });
  });

  group('timeline', () {
    // Newest first, as stored by the repository.
    final trips = [
      _trip('2', Destination.heilbronn, DateTime(2026, 10, 9, 18)),
      _trip('1', Destination.muenchen, DateTime(2026, 10, 5, 8)),
    ];

    test('travel days count for both cities', () {
      expect(locationsOn(trips, DateTime(2026, 10, 4)), isEmpty);
      expect(locationsOn(trips, DateTime(2026, 10, 5)), {Destination.muenchen});
      expect(locationsOn(trips, DateTime(2026, 10, 9)),
          {Destination.muenchen, Destination.heilbronn});
      expect(locationsOn(trips, DateTime(2026, 10, 10)), {Destination.heilbronn});
    });

    test('days at a place stop at today', () {
      expect(
        daysAt(trips, Destination.muenchen, DateTime(2026, 10),
            DateTime(2026, 11), now: DateTime(2026, 10, 31)),
        5, // 5th to 9th
      );
      expect(
        daysAt(trips, Destination.heilbronn, DateTime(2026, 10),
            DateTime(2026, 11), now: DateTime(2026, 10, 20)),
        12, // 9th to 20th
      );
    });
  });

  group('tax summary', () {
    test('sums only study-related costs incl. car and Deutschlandticket', () {
      const settings =
          AppSettings(kmRate: 0.30, studyLocation: Destination.muenchen);
      final trips = [
        _trip('4', Destination.heilbronn, DateTime(2026, 11, 3, 18),
            transport: Transport.auto, km: 250),
        _trip('3', Destination.muenchen, DateTime(2026, 11, 1, 8),
            priceCents: 1000, study: false),
        _trip('2', Destination.heilbronn, DateTime(2026, 10, 9, 18),
            priceCents: 2990),
        _trip('1', Destination.muenchen, DateTime(2026, 10, 5, 8),
            priceCents: 3500),
      ];
      final summary = summarizeYear(
        trips: trips,
        settings: settings,
        dTickets: const [
          DTicketMonth(year: 2026, month: 10, price: 63, sharePercent: 50),
        ],
        year: 2026,
        now: DateTime(2026, 12, 31),
      );
      final total = summary.total;
      expect(total.studyTrips, 3);
      expect(total.privateTrips, 1);
      expect(total.ticketCosts, closeTo(64.90, 0.001));
      expect(total.dTicketCosts, 31.5);
      expect(total.carKm, 250);
      expect(total.carCosts, closeTo(75, 0.001));
      expect(total.total, closeTo(171.40, 0.001));
      // München: Oct 5–9, then Nov 1–3.
      expect(total.daysAtStudyLocation, 8);
      expect(summary.months[9].total, closeTo(96.40, 0.001));
    });
  });

  group('CSV export', () {
    test('uses German Excel format and escapes fields', () {
      final bytes = buildCsv([
        _trip('1', Destination.muenchen, DateTime(2026, 10, 20, 7, 5),
            note: 'Meeting; "wichtig"', priceCents: 2990),
      ], const AppSettings());
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final lines = utf8.decode(bytes.sublist(3)).trim().split('\r\n');
      expect(
          lines[0],
          'Datum;Wochentag;Uhrzeit;Von;Nach;Anlass;Studienbedingt;'
          'Verkehrsmittel;ICE-Ticket;Km (Pkw);Kosten (EUR);Notiz');
      expect(
          lines[1],
          '20.10.2026;Dienstag;07:05;Heilbronn;München;Vorlesung;Ja;ICE;Ja;;'
          '29,90;"Meeting; ""wichtig"""');
    });
  });

  test('parseCents accepts German and English decimals', () {
    expect(parseCents('29,90'), 2990);
    expect(parseCents('29.9 €'), 2990);
    expect(parseCents(' '), isNull);
    expect(() => parseCents('abc'), throwsFormatException);
  });

  testWidgets('home screen shows current location after adding a trip',
      (tester) async {
    final repo = await _repo();
    await tester.pumpWidget(MunichCounterApp(repository: repo));
    expect(find.text('Noch keine Fahrt erfasst'), findsOneWidget);

    await tester.tap(find.text('Fahrt nach Heilbronn'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prüfung'));
    await tester.pump();
    final price = find.widgetWithText(TextField, 'Ticketpreis');
    await tester.scrollUntilVisible(price, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.enterText(price, '19,90');

    final iceSwitch = find.widgetWithText(SwitchListTile, 'ICE-Ticket vorhanden');
    await tester.ensureVisible(iceSwitch);
    await tester.tap(iceSwitch);
    await tester.pump();

    await tester.ensureVisible(find.text('Fahrt speichern'));
    await tester.tap(find.text('Fahrt speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Sie befinden sich aktuell in'), findsOneWidget);
    final trip = repo.trips.single;
    expect(trip.destination, Destination.heilbronn);
    expect(trip.iceTicket, isFalse);
    expect(trip.purpose, Purpose.pruefung);
    expect(trip.studyRelated, isTrue);
    expect(trip.priceCents, 1990);
  });

  test('PDF exports produce documents', () async {
    final fonts = await _fonts();
    final trips = [
      _trip('1', Destination.muenchen, DateTime(2026, 10, 20),
          priceCents: 2990),
      _trip('2', Destination.heilbronn, DateTime(2026, 10, 24),
          transport: Transport.auto, km: 245),
    ];
    const settings = AppSettings(
        name: 'Test', university: 'TUM', studyLocation: Destination.muenchen);
    final month = await buildPdf(
      trips: trips,
      year: 2026,
      month: 10,
      settings: settings,
      dTicket: const DTicketMonth(year: 2026, month: 10, price: 63),
      fonts: fonts,
    );
    final year = await buildYearPdf(
      trips: trips,
      summary: summarizeYear(
          trips: trips, settings: settings, dTickets: const [], year: 2026),
      settings: settings,
      dTickets: const [],
      fonts: fonts,
    );
    expect(String.fromCharCodes(month.take(4)), '%PDF');
    expect(String.fromCharCodes(year.take(4)), '%PDF');
  });
}
