import 'package:equatable/equatable.dart';
import 'package:voo_analytics/src/domain/entities/heat_map_point.dart';
import 'package:voo_core/src/models/voo_size.dart';

export 'heat_map_point.dart';

class HeatMapData extends Equatable {
  final String screenName;
  final VooSize screenSize;
  final List<HeatMapPoint> points;
  final DateTime startDate;
  final DateTime endDate;
  final int totalEvents;

  const HeatMapData({
    required this.screenName,
    required this.screenSize,
    required this.points,
    required this.startDate,
    required this.endDate,
    required this.totalEvents,
  });

  Map<String, dynamic> toMap() {
    return {
      'screen_name': screenName,
      'screen_width': screenSize.width,
      'screen_height': screenSize.height,
      'points': points.map((p) => p.toMap()).toList(),
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_events': totalEvents,
    };
  }

  factory HeatMapData.fromMap(Map<String, dynamic> map) {
    return HeatMapData(
      screenName: map['screen_name'] as String,
      screenSize: VooSize(
        (map['screen_width'] as num).toDouble(),
        (map['screen_height'] as num).toDouble(),
      ),
      points: (map['points'] as List)
          .map((p) => HeatMapPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      totalEvents: map['total_events'] as int,
    );
  }

  @override
  List<Object> get props => [
    screenName,
    screenSize,
    points,
    startDate,
    endDate,
    totalEvents,
  ];
}
