import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/timeline.dart';
import 'common.dart';

/// Month grid where each day is tinted with the city the user was in.
/// Travel days show both cities as a diagonal split.
class TripCalendar extends StatelessWidget {
  const TripCalendar({
    super.key,
    required this.month,
    required this.trips,
    required this.onDayTap,
  });

  final DateTime month;

  /// All trips, newest first (needed to know where a month starts).
  final List<Trip> trips;
  final ValueChanged<DateTime> onDayTap;

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = first.weekday - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _DayCell(
                  day: DateTime(month.year, month.month, d),
                  today: today,
                  trips: trips,
                  onTap: onDayTap,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final c in Destination.values)
                _Legend(color: c.color, label: c.label),
              _Legend(
                gradient: LinearGradient(colors: [
                  Destination.muenchen.color,
                  Destination.heilbronn.color,
                ]),
                label: 'Reisetag',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.trips,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final List<Trip> trips;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departures = trips
        .where((t) => DateUtils.isSameDay(t.departure, day))
        .toList()
      ..sort((a, b) => a.departure.compareTo(b.departure));
    final isTravelDay = departures.isNotEmpty;
    // Where the user was is only known up to today; future days only show
    // planned trips.
    final place = day.isAfter(today) ? null : locationAt(trips, day);

    BoxDecoration decoration;
    Color textColor;
    if (isTravelDay) {
      final from = departures.first.origin.color;
      final to = departures.last.destination.color;
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [from, from, to, to],
          stops: const [0, 0.5, 0.5, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
      textColor = Colors.white;
    } else if (place != null) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: place.color.withOpacity(0.18),
      );
      textColor = place.color;
    } else {
      decoration = BoxDecoration(borderRadius: BorderRadius.circular(10));
      textColor = theme.colorScheme.outline;
    }
    if (DateUtils.isSameDay(day, today)) {
      decoration = decoration.copyWith(
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(day),
      child: Ink(
        decoration: decoration,
        child: Center(
          child: Text(
            '${day.day}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: isTravelDay ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({this.color, this.gradient, required this.label});

  final Color? color;
  final Gradient? gradient;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color?.withOpacity(0.35),
            gradient: gradient,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
