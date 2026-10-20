import 'package:flutter/material.dart' show DateUtils;

import '../models/trip.dart';

/// Where the user is at [time]: the destination of the latest trip that has
/// started by then. [trips] must be sorted newest first.
Destination? locationAt(List<Trip> trips, DateTime time) {
  for (final trip in trips) {
    if (!trip.departure.isAfter(time)) return trip.destination;
  }
  return null;
}

/// Cities the user was in on [day]: where they woke up, plus the destination
/// of every trip departing that day. [trips] must be sorted newest first.
Set<Destination> locationsOn(List<Trip> trips, DateTime day) {
  final start = DateUtils.dateOnly(day);
  final end = start.add(const Duration(days: 1));
  final result = <Destination>{};
  final morning = locationAt(trips, start);
  if (morning != null) result.add(morning);
  for (final t in trips) {
    if (!t.departure.isBefore(start) && t.departure.isBefore(end)) {
      result.add(t.destination);
    }
  }
  return result;
}

/// Days in [from, toExclusive) spent at least partly in [place], counting
/// only days up to and including [now] (the future is not known yet).
int daysAt(
  List<Trip> trips,
  Destination place,
  DateTime from,
  DateTime toExclusive, {
  DateTime? now,
}) {
  final last = DateUtils.dateOnly(now ?? DateTime.now());
  var count = 0;
  for (var day = DateUtils.dateOnly(from);
      day.isBefore(toExclusive) && !day.isAfter(last);
      day = DateTime(day.year, day.month, day.day + 1)) {
    if (locationsOn(trips, day).contains(place)) count++;
  }
  return count;
}
