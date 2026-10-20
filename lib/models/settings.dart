import 'trip.dart';

/// User profile and cost parameters for the tax report.
class AppSettings {
  const AppSettings({
    this.name = '',
    this.university = '',
    this.program = '',
    this.studyLocation,
    this.routeKm,
    this.kmRate = 0.30,
    this.dTicketPrice = 63.0,
  });

  final String name;
  final String university;
  final String program;
  final Destination? studyLocation;

  /// One-way München–Heilbronn distance, prefilled for car trips.
  final double? routeKm;

  /// Euro per driven km for car trips.
  final double kmRate;

  /// Default monthly Deutschlandticket price.
  final double dTicketPrice;

  Map<String, dynamic> toJson() => {
        'name': name,
        'university': university,
        'program': program,
        'studyLocation': studyLocation?.name,
        'routeKm': routeKm,
        'kmRate': kmRate,
        'dTicketPrice': dTicketPrice,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        name: json['name'] as String? ?? '',
        university: json['university'] as String? ?? '',
        program: json['program'] as String? ?? '',
        studyLocation: json['studyLocation'] == null
            ? null
            : Destination.fromName(json['studyLocation'] as String),
        routeKm: (json['routeKm'] as num?)?.toDouble(),
        kmRate: (json['kmRate'] as num?)?.toDouble() ?? 0.30,
        dTicketPrice: (json['dTicketPrice'] as num?)?.toDouble() ?? 63.0,
      );
}

/// A Deutschlandticket held in one month, of which [sharePercent] is
/// attributed to the studies.
class DTicketMonth {
  const DTicketMonth({
    required this.year,
    required this.month,
    required this.price,
    this.sharePercent = 100,
  });

  final int year;
  final int month;
  final double price;
  final int sharePercent;

  double get amount => price * sharePercent / 100;

  String get key => keyFor(year, month);

  static String keyFor(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'year': year,
        'month': month,
        'price': price,
        'sharePercent': sharePercent,
      };

  factory DTicketMonth.fromJson(Map<String, dynamic> json) => DTicketMonth(
        year: json['year'] as int,
        month: json['month'] as int,
        price: (json['price'] as num).toDouble(),
        sharePercent: json['sharePercent'] as int? ?? 100,
      );
}
