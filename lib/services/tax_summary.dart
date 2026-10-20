import 'package:intl/intl.dart';

import '../models/settings.dart';
import '../models/trip.dart';
import 'timeline.dart';

final euroFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');
final kmFormat = NumberFormat('#,##0.#', 'de_DE');

/// Ticket price, or driven km × km rate for car trips.
double tripCost(Trip trip, AppSettings settings) =>
    trip.transport == Transport.auto
        ? (trip.distanceKm ?? 0) * settings.kmRate
        : (trip.priceCents ?? 0) / 100;

/// Cost totals of a period. Only study-related trips are counted.
class PeriodSummary {
  PeriodSummary({
    required this.studyTrips,
    required this.privateTrips,
    required this.ticketCosts,
    required this.carKm,
    required this.carCosts,
    required this.dTicketCosts,
    required this.daysAtStudyLocation,
  });

  final int studyTrips;
  final int privateTrips;
  final double ticketCosts;
  final double carKm;
  final double carCosts;
  final double dTicketCosts;

  /// Null when no study location is configured.
  final int? daysAtStudyLocation;

  /// Public transport (single tickets + Deutschlandticket).
  double get publicTransportCosts => ticketCosts + dTicketCosts;
  double get total => publicTransportCosts + carCosts;
}

class YearSummary {
  YearSummary(this.year, this.total, this.months);

  final int year;
  final PeriodSummary total;

  /// Index 0 = January.
  final List<PeriodSummary> months;
}

PeriodSummary summarizePeriod({
  required List<Trip> trips,
  required AppSettings settings,
  required Iterable<DTicketMonth> dTickets,
  required DateTime from,
  required DateTime toExclusive,
  DateTime? now,
}) {
  bool inPeriod(DateTime d) => !d.isBefore(from) && d.isBefore(toExclusive);
  final periodTrips = trips.where((t) => inPeriod(t.departure)).toList();
  final study = periodTrips.where((t) => t.studyRelated).toList();
  final car = study.where((t) => t.transport == Transport.auto);

  return PeriodSummary(
    studyTrips: study.length,
    privateTrips: periodTrips.length - study.length,
    ticketCosts: study
        .where((t) => t.transport != Transport.auto)
        .fold(0.0, (sum, t) => sum + tripCost(t, settings)),
    carKm: car.fold(0.0, (sum, t) => sum + (t.distanceKm ?? 0)),
    carCosts: car.fold(0.0, (sum, t) => sum + tripCost(t, settings)),
    dTicketCosts: dTickets
        .where((d) => inPeriod(DateTime(d.year, d.month)))
        .fold(0.0, (sum, d) => sum + d.amount),
    daysAtStudyLocation: settings.studyLocation == null
        ? null
        : daysAt(trips, settings.studyLocation!, from, toExclusive, now: now),
  );
}

YearSummary summarizeYear({
  required List<Trip> trips,
  required AppSettings settings,
  required Iterable<DTicketMonth> dTickets,
  required int year,
  DateTime? now,
}) {
  PeriodSummary period(DateTime from, DateTime to) => summarizePeriod(
        trips: trips,
        settings: settings,
        dTickets: dTickets,
        from: from,
        toExclusive: to,
        now: now,
      );
  return YearSummary(
    year,
    period(DateTime(year), DateTime(year + 1)),
    [for (var m = 1; m <= 12; m++) period(DateTime(year, m), DateTime(year, m + 1))],
  );
}
