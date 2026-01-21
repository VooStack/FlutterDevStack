/// Pure Dart size class - replaces Flutter's Size in domain layer.
///
/// This is a platform-independent representation of a 2D size.
/// Use [toSize()] extension (from flutter_type_extensions.dart) when
/// you need to convert to Flutter's [Size] in presentation layer.
class VooSize {
  /// The horizontal extent of this size.
  final double width;

  /// The vertical extent of this size.
  final double height;

  /// Creates a size with the given [width] and [height].
  const VooSize(this.width, this.height);

  /// A size with zero width and zero height.
  static const VooSize zero = VooSize(0.0, 0.0);

  /// Creates a square size with the given [dimension] for both width and height.
  const VooSize.square(double dimension)
      : width = dimension,
        height = dimension;

  /// Creates a size with the given [width] and infinite height.
  const VooSize.fromWidth(double width)
      : width = width,
        height = double.infinity;

  /// Creates a size with the given [height] and infinite width.
  const VooSize.fromHeight(double height)
      : width = double.infinity,
        height = height;

  /// Creates a size from the shortest side of a given [size].
  factory VooSize.fromShortestSide(VooSize size) {
    final shortestSide = size.shortestSide;
    return VooSize.square(shortestSide);
  }

  /// The aspect ratio of this size (width / height).
  ///
  /// Returns [double.infinity] if height is zero.
  double get aspectRatio => height != 0.0 ? width / height : double.infinity;

  /// Whether this size is empty (has zero or negative dimensions).
  bool get isEmpty => width <= 0.0 || height <= 0.0;

  /// Whether this size has positive width and height.
  bool get isNotEmpty => !isEmpty;

  /// The lesser of the magnitudes of the width and height.
  double get shortestSide => width < height ? width : height;

  /// The greater of the magnitudes of the width and height.
  double get longestSide => width > height ? width : height;

  /// Whether this size encloses a non-zero area.
  bool get hasPositiveArea => width > 0.0 && height > 0.0;

  /// Returns a size scaled by the given [operand].
  VooSize operator *(double operand) =>
      VooSize(width * operand, height * operand);

  /// Returns a size scaled by the inverse of the given [operand].
  VooSize operator /(double operand) =>
      VooSize(width / operand, height / operand);

  /// Returns a size scaled by integer division.
  VooSize operator ~/(double operand) =>
      VooSize((width ~/ operand).toDouble(), (height ~/ operand).toDouble());

  /// Returns a size with modulo applied.
  VooSize operator %(double operand) =>
      VooSize(width % operand, height % operand);

  /// Linearly interpolates between two sizes.
  ///
  /// Returns `a + (b - a) * t`.
  static VooSize lerp(VooSize a, VooSize b, double t) {
    return VooSize(
      a.width + (b.width - a.width) * t,
      a.height + (b.height - a.height) * t,
    );
  }

  /// Returns a size that is at least as big as the given [minimum] size.
  VooSize constrain(VooSize minimum) {
    return VooSize(
      width < minimum.width ? minimum.width : width,
      height < minimum.height ? minimum.height : height,
    );
  }

  /// Converts this size to a JSON-serializable map.
  Map<String, dynamic> toJson() => {'width': width, 'height': height};

  /// Creates a size from a JSON map.
  factory VooSize.fromJson(Map<String, dynamic> json) => VooSize(
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VooSize && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'VooSize($width, $height)';
}
