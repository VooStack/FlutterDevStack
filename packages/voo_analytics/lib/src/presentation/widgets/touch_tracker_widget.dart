import 'package:flutter/material.dart';
import 'package:voo_analytics/src/data/repositories/analytics_repository_impl.dart';
import 'package:voo_analytics/src/domain/entities/touch_event.dart';
import 'package:voo_analytics/src/replay/replay_capture_service.dart';
import 'package:voo_analytics/src/voo_analytics_plugin.dart';
import 'package:voo_core/voo_core.dart';

class TouchTrackerWidget extends StatefulWidget {
  final Widget child;

  /// Static screen name (used if screenNameProvider is null)
  final String? screenName;

  /// Dynamic screen name provider - called on each touch event.
  /// Use this when the screen name can change (e.g., for app-wide tracking).
  final String Function()? screenNameProvider;

  final bool enabled;

  const TouchTrackerWidget({
    super.key,
    required this.child,
    this.screenName,
    this.screenNameProvider,
    this.enabled = true,
  }) : assert(screenName != null || screenNameProvider != null,
            'Either screenName or screenNameProvider must be provided');

  @override
  State<TouchTrackerWidget> createState() => _TouchTrackerWidgetState();
}

class _TouchTrackerWidgetState extends State<TouchTrackerWidget> {
  Offset? _lastPosition;
  Size? _screenSize;

  /// Get the current screen name, either from provider or static value
  String get _currentScreenName =>
      widget.screenNameProvider?.call() ?? widget.screenName ?? 'unknown';

  void _logTouchEvent(
    Offset position,
    TouchType type, {
    String? widgetType,
    String? widgetKey,
  }) {
    if (!widget.enabled || !VooAnalyticsPlugin.instance.isInitialized) {
      return;
    }

    // Use last known position for end events if position is zero
    final effectivePosition = (position == Offset.zero && _lastPosition != null)
        ? _lastPosition!
        : position;

    // Update last position if not zero
    if (position != Offset.zero) {
      _lastPosition = position;
    }

    // Get screen name dynamically at touch time (this is also the route)
    final screenName = _currentScreenName;

    final event = TouchEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      position: VooPoint(effectivePosition.dx, effectivePosition.dy),
      screenName: screenName,
      type: type,
      widgetType: widgetType,
      widgetKey: widgetKey,
      route: screenName, // screenName is derived from route observer
    );

    final repository = VooAnalyticsPlugin.instance.repository;
    if (repository is AnalyticsRepositoryImpl) {
      repository.logTouchEvent(event);
    }

    // Touch events are now exported via OTEL in TouchEventMetrics

    // Also capture for replay if enabled
    _captureForReplay(effectivePosition, type);
  }

  void _captureForReplay(Offset position, TouchType type) {
    if (!ReplayCaptureService.instance.isEnabled) return;

    // Get screen size for normalization
    final size = _screenSize;
    if (size == null || size.width == 0 || size.height == 0) return;

    // Normalize coordinates to 0-1 range
    final normalizedX = (position.dx / size.width).clamp(0.0, 1.0);
    final normalizedY = (position.dy / size.height).clamp(0.0, 1.0);

    // Map TouchType to replay touch type string
    final touchTypeStr = switch (type) {
      TouchType.tap => 'tap',
      TouchType.doubleTap => 'doubleTap',
      TouchType.longPress => 'longPress',
      TouchType.panStart => 'panStart',
      TouchType.panUpdate => 'panUpdate',
      TouchType.panEnd => 'panEnd',
      TouchType.scaleStart => 'scaleStart',
      TouchType.scaleUpdate => 'scaleUpdate',
      TouchType.scaleEnd => 'scaleEnd',
    };

    ReplayCaptureService.instance.captureTouch(
      x: normalizedX,
      y: normalizedY,
      touchType: touchTypeStr,
      screenName: _currentScreenName,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    // Cache screen size for coordinate normalization
    _screenSize = MediaQuery.sizeOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        _logTouchEvent(details.localPosition, TouchType.tap);
      },
      onDoubleTapDown: (details) {
        _logTouchEvent(details.localPosition, TouchType.doubleTap);
      },
      onLongPressStart: (details) {
        _logTouchEvent(details.localPosition, TouchType.longPress);
      },
      onScaleStart: (details) {
        // Scale gestures handle both pan and scale
        if (details.pointerCount == 1) {
          _logTouchEvent(details.localFocalPoint, TouchType.panStart);
        } else {
          _logTouchEvent(details.localFocalPoint, TouchType.scaleStart);
        }
      },
      onScaleUpdate: (details) {
        // Throttle update events - only log every 10th update to avoid overwhelming
        if (DateTime.now().millisecondsSinceEpoch % 10 == 0) {
          if (details.pointerCount == 1) {
            _logTouchEvent(details.localFocalPoint, TouchType.panUpdate);
          } else {
            _logTouchEvent(details.localFocalPoint, TouchType.scaleUpdate);
          }
        }
        // Always update last position
        _lastPosition = details.localFocalPoint;
      },
      onScaleEnd: (details) {
        if (details.pointerCount == 1) {
          _logTouchEvent(Offset.zero, TouchType.panEnd);
        } else {
          _logTouchEvent(Offset.zero, TouchType.scaleEnd);
        }
      },
      child: widget.child,
    );
  }
}
