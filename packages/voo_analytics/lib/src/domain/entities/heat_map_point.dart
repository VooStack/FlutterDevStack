import 'package:equatable/equatable.dart';
import 'package:voo_analytics/src/domain/entities/touch_event.dart';
import 'package:voo_core/voo_core.dart';

class HeatMapPoint extends Equatable {
  final VooPoint position;
  final double intensity;
  final int count;
  final TouchType primaryType;

  const HeatMapPoint({required this.position, required this.intensity, required this.count, required this.primaryType});

  Map<String, dynamic> toMap() {
    return {'x': position.x, 'y': position.y, 'intensity': intensity, 'count': count, 'primary_type': primaryType.name};
  }

  factory HeatMapPoint.fromMap(Map<String, dynamic> map) {
    return HeatMapPoint(
      position: VooPoint((map['x'] as num).toDouble(), (map['y'] as num).toDouble()),
      intensity: (map['intensity'] as num).toDouble(),
      count: map['count'] as int,
      primaryType: TouchType.values.firstWhere((e) => e.name == map['primary_type'], orElse: () => TouchType.tap),
    );
  }

  @override
  List<Object> get props => [position, intensity, count, primaryType];
}
