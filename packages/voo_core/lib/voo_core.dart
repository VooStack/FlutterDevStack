// Core functionality
export 'package:voo_core/src/voo.dart';
export 'package:voo_core/src/voo_options.dart';
export 'package:voo_core/src/voo_plugin.dart';

// Models - Configuration and Context
export 'package:voo_core/src/models/voo_config.dart';
export 'package:voo_core/src/models/voo_context.dart';
export 'package:voo_core/src/models/voo_device_info.dart';
export 'package:voo_core/src/models/voo_user_context.dart';
export 'package:voo_core/src/models/voo_breadcrumb.dart';
export 'package:voo_core/src/models/voo_feature.dart';
export 'package:voo_core/src/models/voo_feature_config.dart';

// Models - Pure Dart Foundation Types
export 'package:voo_core/src/models/voo_point.dart';
export 'package:voo_core/src/models/voo_size.dart';

// Services - Device Info Collection
export 'package:voo_core/src/services/voo_device_info_service.dart';

// Services - Background Processing
export 'package:voo_core/src/services/voo_isolate_manager.dart';

// Services - Runtime Metrics
export 'package:voo_core/src/services/voo_runtime_metrics_service.dart';

// Services - Breadcrumb Trail
export 'package:voo_core/src/services/voo_breadcrumb_service.dart';

// Services - Error Tracking
export 'package:voo_core/src/services/voo_error_tracking_service.dart';

// Services - Feature Configuration
export 'package:voo_core/src/services/voo_feature_config_service.dart';

// Exceptions
export 'package:voo_core/src/exceptions/voo_exception.dart';

// Utilities
export 'package:voo_core/src/utils/platform_utils.dart';
export 'package:voo_core/src/utils/flutter_type_extensions.dart';
export 'package:voo_core/src/utils/map_equality.dart';

// Interceptors
export 'package:voo_core/src/interceptors/base_interceptor.dart';

// Metrics
export 'package:voo_core/src/metrics/performance_metrics.dart';

// Analytics
export 'package:voo_core/src/analytics/analytics_event.dart';

// Sync Services
export 'package:voo_core/src/config/base_sync_config.dart';
export 'package:voo_core/src/services/base_sync_service.dart';

// Batching
export 'package:voo_core/src/batching/adaptive_batch_manager.dart';
export 'package:voo_core/src/batching/batch_config.dart';
export 'package:voo_core/src/batching/compression_utils.dart';
export 'package:voo_core/src/batching/network_monitor.dart';
export 'package:voo_core/src/batching/persistent_queue.dart';
export 'package:voo_core/src/batching/retry_policy.dart';
