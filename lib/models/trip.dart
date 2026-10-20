enum Destination {
  muenchen('München'),
  heilbronn('Heilbronn');

  const Destination(this.label);
  final String label;

  Destination get other =>
      this == Destination.muenchen ? Destination.heilbronn : Destination.muenchen;

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

enum Purpose {
  vorlesung('Vorlesung'),
  pruefung('Prüfung'),
  lerngruppe('Lerngruppe'),
  abschlussarbeit('Abschlussarbeit'),
  privat('Privat'),
  sonstiges('Sonstiges');

  const Purpose(this.label);
  final String label;

  static Purpose? tryParse(String? name) =>
      Purpose.values.where((p) => p.name == name).firstOrNull;
}

class Trip {
  const Trip({
    required this.id,
    required this.destination,
    required this.departure,
    required this.transport,
    required this.iceTicket,
    this.note = '',
    this.purpose,
    this.studyRelated = true,
    this.priceCents,
    this.distanceKm,
  });

  final String id;
  final Destination destination;
  final DateTime departure;
  final Transport transport;
  final bool iceTicket;
  final String note;

  /// Null for trips recorded before purposes existed.
  final Purpose? purpose;

  /// Only study-related trips count towards the tax report.
  final bool studyRelated;

  /// Ticket price; used for every transport except [Transport.auto].
  final int? priceCents;

  /// Driven distance; only used for [Transport.auto].
  final double? distanceKm;

  Destination get origin => destination.other;

  Map<String, dynamic> toJson() => {
        'id': id,
        'destination': destination.name,
        'departure': departure.toIso8601String(),
        'transport': transport.name,
        'iceTicket': iceTicket,
        'note': note,
        'purpose': purpose?.name,
        'studyRelated': studyRelated,
        'priceCents': priceCents,
        'distanceKm': distanceKm,
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        destination: Destination.fromName(json['destination'] as String),
        departure: DateTime.parse(json['departure'] as String),
        transport: Transport.fromName(json['transport'] as String? ?? ''),
        iceTicket: json['iceTicket'] as bool? ?? false,
        note: json['note'] as String? ?? '',
        purpose: Purpose.tryParse(json['purpose'] as String?),
        studyRelated: json['studyRelated'] as bool? ?? true,
        priceCents: (json['priceCents'] as num?)?.toInt(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      );
}
