import 'package:flutter/material.dart';
import 'package:voo_analytics/src/data/services/screen_engagement_service.dart';
import 'package:voo_analytics/src/presentation/models/voo_interaction_event.dart';
import 'package:voo_core/voo_core.dart';

/// Wrap any widget to automatically track interactions.
///
/// This widget intercepts gestures and reports them to the analytics system
/// without affecting the wrapped widget's behavior.
///
/// ## Usage
///
/// ```dart
/// VooTrackable(
///   trackingId: 'checkout_button',
///   trackingType: 'button',
///   child: ElevatedButton(
///     onPressed: () => checkout(),
///     child: Text('Checkout'),
///   ),
/// )
/// ```
///
/// ## Interaction Types
///
/// By default, taps are tracked. Enable other interactions as needed:
///
/// ```dart
/// VooTrackable(
///   trackingId: 'product_card',
///   trackingType: 'card',
///   trackTaps: true,
///   trackLongPress: true,
///   trackDoubleTap: true,
///   customParams: {'product_id': '123'},
///   child: ProductCard(product: product),
/// )
/// ```
class VooTrackable extends StatelessWidget {
  /// The widget to track interactions on.
  final Widget child;

  /// Unique identifier for this trackable element.
  ///
  /// Used to identify which element was interacted with in analytics.
  /// Examples: 'login_button', 'product_card_123', 'nav_home'.
  final String? trackingId;

  /// Semantic type of the element.
  ///
  /// Used to categorize interactions by element type.
  /// Examples: 'button', 'link', 'card', 'input', 'toggle'.
  final String? trackingType;

  /// Whether to track tap events.
  final bool trackTaps;

  /// Whether to track double tap events.
  final bool trackDoubleTap;

  /// Whether to track long press events.
  final bool trackLongPress;

  /// Whether to track tap position (local and global coordinates).
  final bool trackPosition;

  /// Custom parameters to include with every interaction.
  final Map<String, dynamic>? customParams;

  /// Optional callback when an interaction is tracked.
  final void Function(VooInteractionEvent event)? onInteractionTracked;

  /// Whether tracking is enabled.
  ///
  /// Set to false to temporarily disable tracking without removing the widget.
  final bool enabled;

  /// The gesture detector behavior.
  final HitTestBehavior? behavior;

  const VooTrackable({
    super.key,
    required this.child,
    this.trackingId,
    this.trackingType,
    this.trackTaps = true,
    this.trackDoubleTap = false,
    this.trackLongPress = false,
    this.trackPosition = false,
    this.customParams,
    this.onInteractionTracked,
    this.enabled = true,
    this.behavior,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return GestureDetector(
      behavior: behavior ?? HitTestBehavior.translucent,
      onTapUp: trackTaps ? (details) => _trackInteraction(VooInteractionType.tap, details: details) : null,
      onDoubleTapDown: trackDoubleTap ? (details) => _trackInteraction(VooInteractionType.doubleTap, tapDownDetails: details) : null,
      onLongPressStart: trackLongPress ? (details) => _trackInteraction(VooInteractionType.longPress, longPressDetails: details) : null,
      child: child,
    );
  }

  void _trackInteraction(
    VooInteractionType type, {
    TapUpDetails? details,
    TapDownDetails? tapDownDetails,
    LongPressStartDetails? longPressDetails,
  }) {
    // Get position if available and tracking is enabled
    Offset? localPosition;
    Offset? globalPosition;

    if (trackPosition) {
      if (details != null) {
        localPosition = details.localPosition;
        globalPosition = details.globalPosition;
      } else if (tapDownDetails != null) {
        localPosition = tapDownDetails.localPosition;
        globalPosition = tapDownDetails.globalPosition;
      } else if (longPressDetails != null) {
        localPosition = longPressDetails.localPosition;
        globalPosition = longPressDetails.globalPosition;
      }
    }

    // Create the interaction event
    final event = VooInteractionEvent(
      type: type,
      elementId: trackingId,
      elementType: trackingType,
      screenName: ScreenEngagementService.currentScreen,
      localPosition: localPosition,
      globalPosition: globalPosition,
      timestamp: DateTime.now(),
      customParams: customParams,
    );

    // Record in screen engagement service
    ScreenEngagementService.recordInteraction(
      type.name,
      elementId: trackingId,
      elementType: trackingType,
      data: event.toJson(),
    );

    // Add as breadcrumb for error context
    _addBreadcrumb(event);

    // Call optional callback
    onInteractionTracked?.call(event);
  }

  void _addBreadcrumb(VooInteractionEvent event) {
    try {
      Voo.addBreadcrumb(VooBreadcrumb(
        type: VooBreadcrumbType.user,
        category: 'ui.${event.typeName}',
        message: 'User ${event.typeName} on ${event.elementType ?? 'element'}: ${event.elementId ?? 'unknown'}',
        data: {
          if (event.elementId != null) 'element_id': event.elementId,
          if (event.elementType != null) 'element_type': event.elementType,
          if (event.screenName != null) 'screen_name': event.screenName,
          if (event.customParams != null) ...event.customParams!,
        },
      ));
    } catch (_) {
      // Ignore breadcrumb errors
    }
  }

  /// Create a trackable button wrapper with sensible defaults.
  static VooTrackable button({
    required Widget child,
    required String trackingId,
    Map<String, dynamic>? customParams,
    void Function(VooInteractionEvent)? onInteractionTracked,
  }) =>
      VooTrackable(
        trackingId: trackingId,
        trackingType: 'button',
        customParams: customParams,
        onInteractionTracked: onInteractionTracked,
        child: child,
      );

  /// Create a trackable link wrapper with sensible defaults.
  static VooTrackable link({
    required Widget child,
    required String trackingId,
    Map<String, dynamic>? customParams,
    void Function(VooInteractionEvent)? onInteractionTracked,
  }) =>
      VooTrackable(
        trackingId: trackingId,
        trackingType: 'link',
        customParams: customParams,
        onInteractionTracked: onInteractionTracked,
        child: child,
      );

  /// Create a trackable card wrapper with sensible defaults.
  static VooTrackable card({
    required Widget child,
    required String trackingId,
    bool trackLongPress = true,
    Map<String, dynamic>? customParams,
    void Function(VooInteractionEvent)? onInteractionTracked,
  }) =>
      VooTrackable(
        trackingId: trackingId,
        trackingType: 'card',
        trackLongPress: trackLongPress,
        customParams: customParams,
        onInteractionTracked: onInteractionTracked,
        child: child,
      );

  /// Create a trackable list item wrapper with sensible defaults.
  static VooTrackable listItem({
    required Widget child,
    required String trackingId,
    bool trackLongPress = true,
    Map<String, dynamic>? customParams,
    void Function(VooInteractionEvent)? onInteractionTracked,
  }) =>
      VooTrackable(
        trackingId: trackingId,
        trackingType: 'list_item',
        trackLongPress: trackLongPress,
        customParams: customParams,
        onInteractionTracked: onInteractionTracked,
        child: child,
      );
}

/// Extension to easily wrap any widget with tracking.
extension VooTrackableExtension on Widget {
  /// Wrap this widget with tracking.
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => doSomething(),
  ///   child: Text('Click me'),
  /// ).withTracking(trackingId: 'my_button', trackingType: 'button')
  /// ```
  VooTrackable withTracking({
    String? trackingId,
    String? trackingType,
    bool trackTaps = true,
    bool trackDoubleTap = false,
    bool trackLongPress = false,
    bool trackPosition = false,
    Map<String, dynamic>? customParams,
    void Function(VooInteractionEvent event)? onInteractionTracked,
    bool enabled = true,
  }) =>
      VooTrackable(
        trackingId: trackingId,
        trackingType: trackingType,
        trackTaps: trackTaps,
        trackDoubleTap: trackDoubleTap,
        trackLongPress: trackLongPress,
        trackPosition: trackPosition,
        customParams: customParams,
        onInteractionTracked: onInteractionTracked,
        enabled: enabled,
        child: this,
      );
}
