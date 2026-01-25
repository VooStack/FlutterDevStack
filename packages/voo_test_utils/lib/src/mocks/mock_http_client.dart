import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A captured HTTP request for test verification.
class CapturedRequest {
  final http.Request request;
  final DateTime timestamp;

  CapturedRequest(this.request) : timestamp = DateTime.now();

  String get method => request.method;
  String get url => request.url.toString();
  Map<String, String> get headers => request.headers;
  String get body => request.body;
}

/// Factory for creating mock HTTP clients with request capture.
class MockHttpClient {
  final List<CapturedRequest> capturedRequests = [];
  int requestCount = 0;

  /// Creates a MockClient that returns success responses.
  MockClient createMockClient({
    int statusCode = 200,
    String body = '{"success": true}',
    Duration? delay,
    bool Function(http.Request)? shouldFail,
    int failStatusCode = 500,
    String failBody = '{"error": "failed"}',
  }) => MockClient((request) async {
    capturedRequests.add(CapturedRequest(request));
    requestCount++;

    if (delay != null) {
      await Future<void>.delayed(delay);
    }

    if (shouldFail != null && shouldFail(request)) {
      return http.Response(failBody, failStatusCode);
    }

    return http.Response(body, statusCode);
  });

  /// Creates a MockClient that returns different responses based on request count.
  MockClient createSequentialMockClient(List<http.Response> responses) {
    int index = 0;
    return MockClient((request) async {
      capturedRequests.add(CapturedRequest(request));
      requestCount++;

      if (index < responses.length) {
        return responses[index++];
      }
      return http.Response('{"success": true}', 200);
    });
  }

  /// Creates a MockClient that fails a certain number of times then succeeds.
  MockClient createRetryMockClient({int failCount = 2, int failStatusCode = 500, String successBody = '{"success": true}'}) {
    int attempts = 0;
    return MockClient((request) async {
      capturedRequests.add(CapturedRequest(request));
      requestCount++;
      attempts++;

      if (attempts <= failCount) {
        return http.Response('{"error": "failed"}', failStatusCode);
      }
      return http.Response(successBody, 200);
    });
  }

  /// Clears all captured requests and resets the counter.
  void reset() {
    capturedRequests.clear();
    requestCount = 0;
  }

  /// Gets the most recent request.
  CapturedRequest? get lastRequest => capturedRequests.isNotEmpty ? capturedRequests.last : null;

  /// Gets all request bodies as a list.
  List<String> get requestBodies => capturedRequests.map((r) => r.body).toList();

  /// Gets all request URLs as a list.
  List<String> get requestUrls => capturedRequests.map((r) => r.url).toList();
}
