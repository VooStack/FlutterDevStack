/// Configuration for VooTelemetry
class TelemetryConfig {
  final String endpoint;
  final String? apiKey;
  final Duration batchInterval;
  final int maxBatchSize;
  final bool debug;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool enableCompression;
  final Map<String, String> headers;

  /// Enable background processing using isolates.
  /// When true, telemetry processing happens off the main thread.
  final bool useBackgroundProcessing;

  /// Enable network-aware batching.
  /// Adjusts batch size and intervals based on network conditions.
  final bool enableNetworkAwareBatching;

  /// Enable persistent queue using Sembast.
  /// Telemetry survives app restarts.
  final bool enablePersistence;

  /// Maximum items in the persistent queue.
  final int maxQueueSize;

  /// Maximum retention period for queued items.
  final Duration maxRetention;

  /// Compression threshold in bytes.
  /// Payloads larger than this will be compressed.
  final int compressionThreshold;

  TelemetryConfig({
    required this.endpoint,
    this.apiKey,
    this.batchInterval = const Duration(seconds: 30),
    this.maxBatchSize = 100,
    this.debug = false,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableCompression = true,
    this.useBackgroundProcessing = false,
    this.enableNetworkAwareBatching = false,
    this.enablePersistence = false,
    this.maxQueueSize = 5000,
    this.maxRetention = const Duration(days: 7),
    this.compressionThreshold = 1024,
    Map<String, String>? headers,
  }) : headers = {'Content-Type': 'application/json', if (apiKey != null) 'X-API-Key': apiKey, ...?headers};

  /// Create a copy with updated values
  TelemetryConfig copyWith({
    String? endpoint,
    String? apiKey,
    Duration? batchInterval,
    int? maxBatchSize,
    bool? debug,
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
    bool? enableCompression,
    bool? useBackgroundProcessing,
    bool? enableNetworkAwareBatching,
    bool? enablePersistence,
    int? maxQueueSize,
    Duration? maxRetention,
    int? compressionThreshold,
    Map<String, String>? headers,
  }) => TelemetryConfig(
    endpoint: endpoint ?? this.endpoint,
    apiKey: apiKey ?? this.apiKey,
    batchInterval: batchInterval ?? this.batchInterval,
    maxBatchSize: maxBatchSize ?? this.maxBatchSize,
    debug: debug ?? this.debug,
    timeout: timeout ?? this.timeout,
    maxRetries: maxRetries ?? this.maxRetries,
    retryDelay: retryDelay ?? this.retryDelay,
    enableCompression: enableCompression ?? this.enableCompression,
    useBackgroundProcessing: useBackgroundProcessing ?? this.useBackgroundProcessing,
    enableNetworkAwareBatching: enableNetworkAwareBatching ?? this.enableNetworkAwareBatching,
    enablePersistence: enablePersistence ?? this.enablePersistence,
    maxQueueSize: maxQueueSize ?? this.maxQueueSize,
    maxRetention: maxRetention ?? this.maxRetention,
    compressionThreshold: compressionThreshold ?? this.compressionThreshold,
    headers: headers ?? this.headers,
  );
}
