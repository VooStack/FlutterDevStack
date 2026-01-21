import 'dart:math';

/// Pure Dart 2D point class - replaces Flutter's Offset in domain layer.
///
/// This is a platform-independent representation of a point in 2D space.
/// Use [toOffset()] extension (from flutter_type_extensions.dart) when
/// you need to convert to Flutter's [Offset] in presentation layer.
class VooPoint {
  /// The x-coordinate of this point.
  final double x;

  /// The y-coordinate of this point.
  final double y;

  /// Creates a point with the given [x] and [y] coordinates.
  const VooPoint(this.x, this.y);

  /// A point at the origin (0, 0).
  static const VooPoint zero = VooPoint(0.0, 0.0);

  /// Alias for [x] - for compatibility with Flutter's Offset.
  double get dx => x;

  /// Alias for [y] - for compatibility with Flutter's Offset.
  double get dy => y;

  /// Returns true if both [x] and [y] are zero.
  bool get isZero => x == 0.0 && y == 0.0;

  /// The distance from the origin to this point.
  double get distance => sqrt(x * x + y * y);

  /// The square of the distance from the origin to this point.
  ///
  /// Use this instead of [distance] when comparing distances,
  /// as it avoids the expensive square root operation.
  double get distanceSquared => x * x + y * y;

  /// Returns a point with the same direction but the given [distance].
  VooPoint withDistance(double distance) {
    if (this.distance == 0.0) return this;
    return this * (distance / this.distance);
  }

  /// Binary addition of two points.
  VooPoint operator +(VooPoint other) => VooPoint(x + other.x, y + other.y);

  /// Binary subtraction of two points.
  VooPoint operator -(VooPoint other) => VooPoint(x - other.x, y - other.y);

  /// Unary negation.
  VooPoint operator -() => VooPoint(-x, -y);

  /// Scalar multiplication.
  VooPoint operator *(double operand) => VooPoint(x * operand, y * operand);

  /// Scalar division.
  VooPoint operator /(double operand) => VooPoint(x / operand, y / operand);

  /// Integer division.
  VooPoint operator ~/(double operand) =>
      VooPoint((x ~/ operand).toDouble(), (y ~/ operand).toDouble());

  /// Modulo operation.
  VooPoint operator %(double operand) => VooPoint(x % operand, y % operand);

  /// Linearly interpolates between two points.
  ///
  /// Returns `a + (b - a) * t`.
  static VooPoint lerp(VooPoint a, VooPoint b, double t) {
    return VooPoint(
      a.x + (b.x - a.x) * t,
      a.y + (b.y - a.y) * t,
    );
  }

  /// Converts this point to a JSON-serializable map.
  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  /// Creates a point from a JSON map.
  factory VooPoint.fromJson(Map<String, dynamic> json) => VooPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VooPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'VooPoint($x, $y)';
}
