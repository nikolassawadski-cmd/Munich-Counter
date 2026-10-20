import 'package:flutter/material.dart';

import '../data/trip_repository.dart';
import '../models/trip.dart';
import '../services/haptics.dart';
import '../services/timeline.dart';
import '../widgets/common.dart';
import '../widgets/trip_calendar.dart';
import 'trip_form_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});

  final TripRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  TripRepository get _repository => widget.repository;

  void _showDay(DateTime day) {
    final trips = _repository.trips
        .where((t) => DateUtils.isSameDay(t.departure, day))
        .toList()
        .reversed
        .toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(dayFormat.format(day),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            for (final t in trips)
              TripTile(
                trip: t,
                settings: _repository.settings,
                onTap: () {
                  Navigator.pop(sheetContext);
                  TripFormScreen.open(context, _repository, trip: t);
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  TripFormScreen.open(context, _repository, date: day);
                },
                icon: const Icon(Icons.add),
                label: const Text('Fahrt an diesem Tag eintragen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Fahrt',
        onPressed: () => TripFormScreen.open(context, _repository),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _repository,
        builder: (context, _) {
          final all = _repository.trips;
          // Newest first within the month, like the rest of the app.
          final trips = _repository
              .tripsInMonth(_month.year, _month.month)
              .reversed
              .toList();
          final monthEnd = DateTime(_month.year, _month.month + 1);
          final theme = Theme.of(context);

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              MonthSwitcher(
                month: _month,
                onChanged: (m) => setState(() => _month = m),
              ),
              TripCalendar(month: _month, trips: all, onDayTap: _showDay),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  [
                    for (final d in Destination.values)
                      if (daysAt(all, d, _month, monthEnd) case final n)
                        '$n ${n == 1 ? 'Tag' : 'Tage'} in ${d.label}',
                  ].join('  ·  '),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const Divider(height: 24),
              if (trips.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Keine Fahrten in diesem Monat',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              for (final trip in trips)
                Dismissible(
                  key: ValueKey(trip.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child:
                        Icon(Icons.delete, color: theme.colorScheme.onError),
                  ),
                  onDismissed: (_) {
                    hapticTick();
                    _repository.delete(trip.id);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(
                            'Fahrt nach ${trip.destination.label} gelöscht'),
                        action: SnackBarAction(
                          label: 'Rückgängig',
                          onPressed: () => _repository.add(trip),
                        ),
                      ));
                  },
                  child: TripTile(
                    trip: trip,
                    settings: _repository.settings,
                    onTap: () =>
                        TripFormScreen.open(context, _repository, trip: trip),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
