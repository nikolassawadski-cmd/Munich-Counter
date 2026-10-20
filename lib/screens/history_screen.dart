import 'package:flutter/material.dart';

import '../data/trip_repository.dart';
import '../widgets/common.dart';
import 'trip_form_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});

  final TripRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Fahrt',
        onPressed: () => TripFormScreen.open(context, repository),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          // Newest first within the month, like the rest of the app.
          final trips = repository
              .tripsInMonth(_month.year, _month.month)
              .reversed
              .toList();
          return Column(
            children: [
              MonthSwitcher(
                month: _month,
                onChanged: (m) => setState(() => _month = m),
              ),
              const Divider(height: 1),
              Expanded(
                child: trips.isEmpty
                    ? Center(
                        child: Text(
                          'Keine Fahrten in diesem Monat',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: trips.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final trip = trips[i];
                          return Dismissible(
                            key: ValueKey(trip.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(context).colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: Icon(Icons.delete,
                                  color: Theme.of(context).colorScheme.onError),
                            ),
                            onDismissed: (_) {
                              repository.delete(trip.id);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(
                                  content: Text(
                                      'Fahrt nach ${trip.destination.label} gelöscht'),
                                  action: SnackBarAction(
                                    label: 'Rückgängig',
                                    onPressed: () => repository.add(trip),
                                  ),
                                ));
                            },
                            child: TripTile(
                              trip: trip,
                              onTap: () => TripFormScreen.open(
                                  context, repository,
                                  trip: trip),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
