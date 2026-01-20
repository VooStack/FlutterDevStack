import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Result of processing a screenshot in an isolate.
class ScreenshotProcessingResult {
  /// Base64 encoded screenshot data.
  final String base64Data;

  /// SHA256 content hash of the original bytes.
  final String contentHash;

  /// Size of the original bytes.
  final int sizeBytes;

  const ScreenshotProcessingResult({
    required this.base64Data,
    required this.contentHash,
    required this.sizeBytes,
  });
}

/// Isolate processing utilities for heavy operations.
///
/// These functions use [compute] to run expensive operations off the main thread,
/// preventing UI jank during screenshot capture and data processing.
class IsolateProcessing {
  IsolateProcessing._();

  /// Process screenshot bytes in an isolate.
  ///
  /// This performs base64 encoding and SHA256 hashing off the main thread.
  /// Returns a [ScreenshotProcessingResult] with the encoded data and hash.
  ///
  /// Example:
  /// ```dart
  /// final result = await IsolateProcessing.processScreenshot(imageBytes);
  /// final base64Data = result.base64Data;
  /// final contentHash = result.contentHash;
  /// ```
  static Future<ScreenshotProcessingResult> processScreenshot(Uint8List bytes) async {
    return compute(_processScreenshotIsolate, bytes);
  }

  /// Encode bytes to base64 in an isolate.
  ///
  /// Use this for encoding large data that would otherwise block the UI.
  static Future<String> encodeToBase64(Uint8List bytes) async {
    return compute(_encodeToBase64Isolate, bytes);
  }

  /// Compute SHA256 hash in an isolate.
  ///
  /// Use this for hashing large data that would otherwise block the UI.
  static Future<String> computeSha256(Uint8List bytes) async {
    return compute(_computeSha256Isolate, bytes);
  }

  /// Compress and process screenshot in an isolate.
  ///
  /// This combines JPEG compression (if quality < 100) with base64 encoding
  /// and hashing. Compression is particularly useful for reducing upload size.
  ///
  /// Note: JPEG compression requires additional image processing that may
  /// not be available in isolates. For now, this just processes the raw bytes.
  static Future<ScreenshotProcessingResult> processAndCompress(
    Uint8List bytes, {
    int quality = 85,
  }) async {
    // For now, just process without compression
    // JPEG compression would require image manipulation libraries
    return compute(_processScreenshotIsolate, bytes);
  }
}

// Top-level functions for isolate execution
// These must be top-level or static for compute() to work

ScreenshotProcessingResult _processScreenshotIsolate(Uint8List bytes) {
  final base64Data = base64Encode(bytes);
  final contentHash = sha256.convert(bytes).toString();
  return ScreenshotProcessingResult(
    base64Data: base64Data,
    contentHash: contentHash,
    sizeBytes: bytes.length,
  );
}

String _encodeToBase64Isolate(Uint8List bytes) {
  return base64Encode(bytes);
}

String _computeSha256Isolate(Uint8List bytes) {
  return sha256.convert(bytes).toString();
}
