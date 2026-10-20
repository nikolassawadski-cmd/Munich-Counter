enum Destination {
  muenchen('München'),
  heilbronn('Heilbronn');

  const Destination(this.label);
  final String label;

  static Destination fromName(String name) =>
      Destination.values.firstWhere((d) => d.name == name);
}

enum Transport {
  ice('ICE'),
  icEc('IC/EC'),
  regional('Regionalzug'),
  auto('Auto'),
  sonstiges('Sonstiges');

  const Transport(this.label);
  final String label;

  static Transport fromName(String name) => Transport.values
      .firstWhere((t) => t.name == name, orElse: () => Transport.sonstiges);
}

class Trip {
  const Trip({
    required this.id,
    required this.destination,
    required this.departure,
    required this.transport,
    required this.iceTicket,
    this.note = '',
  });

  final String id;
  final Destination destination;
  final DateTime departure;
  final Transport transport;
  final bool iceTicket;
  final String note;

  Trip copyWith({
    Destination? destination,
    DateTime? departure,
    Transport? transport,
    bool? iceTicket,
    String? note,
  }) =>
      Trip(
        id: id,
        destination: destination ?? this.destination,
        departure: departure ?? this.departure,
        transport: transport ?? this.transport,
        iceTicket: iceTicket ?? this.iceTicket,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'destination': destination.name,
        'departure': departure.toIso8601String(),
        'transport': transport.name,
        'iceTicket': iceTicket,
        'note': note,
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        destination: Destination.fromName(json['destination'] as String),
        departure: DateTime.parse(json['departure'] as String),
        transport: Transport.fromName(json['transport'] as String? ?? ''),
        iceTicket: json['iceTicket'] as bool? ?? false,
        note: json['note'] as String? ?? '',
      );
}
