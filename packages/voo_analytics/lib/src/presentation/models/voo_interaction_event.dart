import 'package:flutter/material.dart';

/// Type of trackable interaction.
enum VooInteractionType {
  /// A tap/click event.
  tap,

  /// A double tap event.
  doubleTap,

  /// A long press event.
  longPress,

  /// A swipe gesture.
  swipe,

  /// A scroll event.
  scroll,

  /// Custom interaction type.
  custom,
}

/// Details about a tracked interaction.
@immutable
class VooInteractionEvent {
  /// Type of interaction.
  final VooInteractionType type;

  /// Custom type name for [VooInteractionType.custom].
  final String? customType;

  /// Unique identifier for the tracked element.
  final String? elementId;

  /// Semantic type of the element (button, link, card, etc.).
  final String? elementType;

  /// Screen name where the interaction occurred.
  final String? screenName;

  /// Position of the interaction in local coordinates.
  final Offset? localPosition;

  /// Position of the interaction in global coordinates.
  final Offset? globalPosition;

  /// Timestamp of the interaction.
  final DateTime timestamp;

  /// Custom parameters attached to this interaction.
  final Map<String, dynamic>? customParams;

  const VooInteractionEvent({
    required this.type,
    this.customType,
    this.elementId,
    this.elementType,
    this.screenName,
    this.localPosition,
    this.globalPosition,
    required this.timestamp,
    this.customParams,
  });

  /// Get the interaction type name.
  String get typeName => type == VooInteractionType.custom ? (customType ?? 'custom') : type.name;

  Map<String, dynamic> toJson() => {
    'type': typeName,
    if (elementId != null) 'element_id': elementId,
    if (elementType != null) 'element_type': elementType,
    if (screenName != null) 'screen_name': screenName,
    if (localPosition != null) 'local_position': {'x': localPosition!.dx, 'y': localPosition!.dy},
    if (globalPosition != null) 'global_position': {'x': globalPosition!.dx, 'y': globalPosition!.dy},
    'timestamp': timestamp.toIso8601String(),
    if (customParams != null) ...customParams!,
  };

  @override
  String toString() => 'VooInteractionEvent($typeName on $elementId)';
}
