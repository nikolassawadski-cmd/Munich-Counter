import 'package:flutter/material.dart';

import '../data/trip_repository.dart';
import '../models/trip.dart';
import '../widgets/common.dart';
import 'trip_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.onShowHistory,
  });

  final TripRepository repository;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final now = DateTime.now();
        final location = repository.currentLocation(now);
        final monthTrips = repository.tripsInMonth(now.year, now.month);
        final recent = repository.trips.take(3).toList();
        final theme = Theme.of(context);

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LocationCard(location: location, lastTrip: repository.lastTrip),
              const SizedBox(height: 24),
              Text('Fahrt eintragen', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final d in Destination.values) ...[
                _TripButton(
                  destination: d,
                  // The trip away from the current city is the likely next one.
                  highlighted: d != location,
                  onPressed: () =>
                      TripFormScreen.open(context, repository, destination: d),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              Text(monthFormat.format(now), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in Destination.values) ...[
                    StatChip(
                      value:
                          '${monthTrips.where((t) => t.destination == d).length}',
                      label: 'nach ${d.label}',
                      color: d.color,
                    ),
                    const SizedBox(width: 8),
                  ],
                  StatChip(
                    value: '${monthTrips.where((t) => t.iceTicket).length}',
                    label: 'mit ICE-Ticket',
                    color: Colors.green.shade700,
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text('Letzte Fahrten',
                          style: theme.textTheme.titleMedium),
                    ),
                    TextButton(
                      onPressed: onShowHistory,
                      child: const Text('Alle anzeigen'),
                    ),
                  ],
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final t in recent)
                        TripTile(
                          trip: t,
                          settings: repository.settings,
                          onTap: () =>
                              TripFormScreen.open(context, repository, trip: t),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.lastTrip});

  final Destination? location;
  final Trip? lastTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = location?.color ?? theme.colorScheme.outline;
    final onColor = location == null ? theme.colorScheme.onSurface : Colors.white;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: location == null
            ? null
            : LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.35)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: location == null ? theme.colorScheme.surfaceContainerHighest : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(location?.icon ?? Icons.help_outline, color: onColor, size: 36),
          const SizedBox(height: 16),
          if (location == null) ...[
            Text('Noch keine Fahrt erfasst',
                style: theme.textTheme.headlineSmall?.copyWith(color: onColor)),
            const SizedBox(height: 4),
            Text(
              'Trage deine erste Fahrt ein, dann siehst du hier, wo du dich gerade befindest.',
              style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
            ),
          ] else ...[
            Text('Sie befinden sich aktuell in',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: onColor.withOpacity(0.85))),
            Text(
              location!.label,
              style: theme.textTheme.displaySmall
                  ?.copyWith(color: onColor, fontWeight: FontWeight.bold),
            ),
            if (lastTrip != null) ...[
              const SizedBox(height: 12),
              Text(
                'Letzte Fahrt: ${dayFormat.format(lastTrip!.departure)}, '
                '${timeFormat.format(lastTrip!.departure)} Uhr '
                'nach ${lastTrip!.destination.label}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: onColor.withOpacity(0.85)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TripButton extends StatelessWidget {
  const _TripButton({
    required this.destination,
    required this.highlighted,
    required this.onPressed,
  });

  final Destination destination;
  final bool highlighted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = Text('Fahrt nach ${destination.label}',
        style: const TextStyle(fontSize: 17));
    final icon = Icon(destination.icon);
    const size = Size.fromHeight(56);
    return highlighted
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: size,
              backgroundColor: destination.color,
            ),
            onPressed: onPressed,
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              foregroundColor: destination.color,
            ),
            onPressed: onPressed,
            icon: icon,
            label: label,
          );
  }
}
