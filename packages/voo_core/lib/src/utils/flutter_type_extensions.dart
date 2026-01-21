import 'package:flutter/material.dart';
import 'package:voo_core/src/models/voo_point.dart';
import 'package:voo_core/src/models/voo_size.dart';

/// Extension to convert [VooPoint] to Flutter's [Offset].
///
/// Use this in the presentation layer when you need to pass
/// a VooPoint to Flutter widgets.
extension VooPointToOffset on VooPoint {
  /// Converts this [VooPoint] to a Flutter [Offset].
  Offset toOffset() => Offset(x, y);
}

/// Extension to convert Flutter's [Offset] to [VooPoint].
///
/// Use this when receiving data from Flutter widgets that needs
/// to be stored in domain entities.
extension OffsetToVooPoint on Offset {
  /// Converts this [Offset] to a [VooPoint].
  VooPoint toVooPoint() => VooPoint(dx, dy);
}

/// Extension to convert [VooSize] to Flutter's [Size].
///
/// Use this in the presentation layer when you need to pass
/// a VooSize to Flutter widgets.
extension VooSizeToSize on VooSize {
  /// Converts this [VooSize] to a Flutter [Size].
  Size toSize() => Size(width, height);
}

/// Extension to convert Flutter's [Size] to [VooSize].
///
/// Use this when receiving data from Flutter widgets that needs
/// to be stored in domain entities.
extension SizeToVooSize on Size {
  /// Converts this [Size] to a [VooSize].
  VooSize toVooSize() => VooSize(width, height);
}
