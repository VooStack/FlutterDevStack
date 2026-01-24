/// Shared testing utilities for VooStack packages.
///
/// This library provides reusable mocks, fixtures, and helpers
/// for testing VooStack components.
library voo_test_utils;

// Mocks
export 'src/mocks/mock_http_client.dart';
export 'src/mocks/mock_voo_core.dart';
export 'src/mocks/mock_telemetry.dart';
export 'src/mocks/mock_platform.dart';

// Fixtures
export 'src/fixtures/config_fixtures.dart';
export 'src/fixtures/telemetry_fixtures.dart';

// Helpers
export 'src/helpers/async_helpers.dart';
export 'src/helpers/cleanup_helpers.dart';
