import 'package:uuid/uuid.dart';

/// Mutable user and session context for Voo SDK.
///
/// This class manages user identification and session state that is
/// shared across all Voo packages. It is automatically created during
/// [Voo.initializeApp] and can be updated throughout the app lifecycle.
///
/// The session ID is auto-generated on initialization and can be refreshed
/// by calling [startNewSession]. User identification is set after
/// authentication via [setUserId].
///
/// Example usage:
/// ```dart
/// // After user logs in
/// Voo.setUserId(user.id);
/// Voo.setUserProperty('plan', 'premium');
///
/// // After user logs out
/// Voo.clearUser();
/// Voo.startNewSession();
/// ```
class VooUserContext {
  String? _userId;
  String _sessionId;
  final Map<String, dynamic> _userProperties;
  DateTime _sessionStartTime;

  /// Creates a new VooUserContext with an auto-generated session ID.
  VooUserContext({String? initialUserId, String? initialSessionId})
      : _userId = initialUserId,
        _sessionId = initialSessionId ?? _generateSessionId(),
        _userProperties = {},
        _sessionStartTime = DateTime.now();

  /// The current user ID, or null if not authenticated.
  String? get userId => _userId;

  /// The current session ID.
  String get sessionId => _sessionId;

  /// Read-only view of user properties.
  Map<String, dynamic> get userProperties => Map.unmodifiable(_userProperties);

  /// When the current session started.
  DateTime get sessionStartTime => _sessionStartTime;

  /// Duration since session started.
  Duration get sessionDuration => DateTime.now().difference(_sessionStartTime);

  /// Whether a user is currently identified.
  bool get isAuthenticated => _userId != null && _userId!.isNotEmpty;

  /// Sets the user ID.
  ///
  /// Call this after user authentication. Pass null or empty string
  /// to clear the user ID (e.g., on logout).
  void setUserId(String? userId) {
    _userId = (userId?.isEmpty ?? true) ? null : userId;
  }

  /// Sets a single user property.
  ///
  /// User properties are included in telemetry sync payloads.
  void setUserProperty(String key, dynamic value) {
    if (value == null) {
      _userProperties.remove(key);
    } else {
      _userProperties[key] = value;
    }
  }

  /// Sets multiple user properties at once.
  ///
  /// Existing properties with the same keys are overwritten.
  void setUserProperties(Map<String, dynamic> properties) {
    for (final entry in properties.entries) {
      setUserProperty(entry.key, entry.value);
    }
  }

  /// Clears all user properties.
  void clearUserProperties() {
    _userProperties.clear();
  }

  /// Clears user identification and properties.
  ///
  /// Call this on logout. The session ID is preserved.
  /// Call [startNewSession] if you also want a new session.
  void clearUser() {
    _userId = null;
    _userProperties.clear();
  }

  /// Starts a new session with an optional custom session ID.
  ///
  /// If no session ID is provided, one is auto-generated.
  /// This also resets the session start time.
  void startNewSession([String? sessionId]) {
    _sessionId = sessionId ?? _generateSessionId();
    _sessionStartTime = DateTime.now();
  }

  /// Returns the context as a sync payload map.
  ///
  /// Used by [VooContext.toSyncPayload] to include user context
  /// in telemetry requests.
  Map<String, dynamic> toSyncPayload() => {
        'sessionId': _sessionId,
        'userId': _userId ?? '',
        ..._userProperties,
      };

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'userId': _userId,
        'sessionId': _sessionId,
        'userProperties': Map<String, dynamic>.from(_userProperties),
        'sessionStartTime': _sessionStartTime.toIso8601String(),
      };

  /// Creates a VooUserContext from a JSON map.
  factory VooUserContext.fromJson(Map<String, dynamic> json) {
    final context = VooUserContext(
      initialUserId: json['userId'] as String?,
      initialSessionId: json['sessionId'] as String?,
    );
    if (json['userProperties'] != null) {
      context.setUserProperties(
        Map<String, dynamic>.from(json['userProperties'] as Map),
      );
    }
    return context;
  }

  static String _generateSessionId() {
    return const Uuid().v4();
  }

  @override
  String toString() {
    return 'VooUserContext(userId: $_userId, sessionId: $_sessionId, '
        'properties: ${_userProperties.length})';
  }
}
