import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';

extension DestinationStyle on Destination {
  Color get color => switch (this) {
        Destination.muenchen => const Color(0xFF1565C0),
        Destination.heilbronn => const Color(0xFFC62828),
      };

  IconData get icon => switch (this) {
        Destination.muenchen => Icons.location_city,
        Destination.heilbronn => Icons.wine_bar,
      };
}

extension TransportStyle on Transport {
  IconData get icon => switch (this) {
        Transport.ice || Transport.icEc => Icons.train,
        Transport.regional => Icons.directions_railway,
        Transport.auto => Icons.directions_car,
        Transport.sonstiges => Icons.more_horiz,
      };
}

final dayFormat = DateFormat('EE, dd.MM.yyyy');
final timeFormat = DateFormat('HH:mm');
final monthFormat = DateFormat('MMMM yyyy');

class TripTile extends StatelessWidget {
  const TripTile({super.key, required this.trip, this.onTap});

  final Trip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = trip.destination;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: d.color.withOpacity(0.15),
        foregroundColor: d.color,
        child: Icon(d.icon),
      ),
      title: Text('nach ${d.label}'),
      subtitle: Text(
        [
          '${dayFormat.format(trip.departure)}, ${timeFormat.format(trip.departure)} Uhr',
          trip.transport.label,
          if (trip.note.isNotEmpty) trip.note,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Tooltip(
        message: trip.iceTicket ? 'ICE-Ticket vorhanden' : 'Kein ICE-Ticket',
        child: Icon(
          trip.iceTicket
              ? Icons.confirmation_number
              : Icons.confirmation_number_outlined,
          color: trip.iceTicket
              ? Colors.green.shade600
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  /// Any date within the selected month.
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    return Row(
      children: [
        IconButton(
          tooltip: 'Vorheriger Monat',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Expanded(
          child: Text(
            monthFormat.format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Nächster Monat',
          icon: const Icon(Icons.chevron_right),
          onPressed: isCurrent
              ? null
              : () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
