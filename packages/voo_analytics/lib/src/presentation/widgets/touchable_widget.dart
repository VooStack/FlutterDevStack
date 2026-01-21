import 'package:flutter/material.dart';
import 'package:voo_analytics/src/data/repositories/analytics_repository_impl.dart';
import 'package:voo_analytics/src/domain/entities/touch_event.dart';
import 'package:voo_analytics/src/voo_analytics_plugin.dart';
import 'package:voo_core/src/models/voo_point.dart';

/// A widget that tracks touch events on its child.
///
/// Use this to track taps on specific UI elements like buttons, cards, etc.
/// The widget type and optional key are included in the touch event for
/// analytics identification.
class TouchableWidget extends StatelessWidget {
  final Widget child;
  final String widgetType;
  final String? widgetKey;
  final VoidCallback? onTap;

  const TouchableWidget({
    super.key,
    required this.child,
    required this.widgetType,
    this.widgetKey,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (VooAnalyticsPlugin.instance.isInitialized) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            final center = Offset(
              position.dx + size.width / 2,
              position.dy + size.height / 2,
            );

            final routeName = ModalRoute.of(context)?.settings.name;
            final screenName = routeName ?? 'unknown';

            final event = TouchEvent(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              timestamp: DateTime.now(),
              position: VooPoint(center.dx, center.dy),
              screenName: screenName,
              type: TouchType.tap,
              widgetType: widgetType,
              widgetKey: widgetKey,
              route: routeName,
            );

            final repository = VooAnalyticsPlugin.instance.repository;
            if (repository is AnalyticsRepositoryImpl) {
              repository.logTouchEvent(event);
            }

            // Cloud sync for heatmaps
            VooAnalyticsPlugin.instance.cloudSyncService?.queueTouchEvent(event);
          }
        }
        onTap?.call();
      },
      child: child,
    );
  }
}
