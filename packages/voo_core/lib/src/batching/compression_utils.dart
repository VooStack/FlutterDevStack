import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Utilities for compressing telemetry payloads.
///
/// Uses gzip compression for payloads over a configurable threshold.
class CompressionUtils {
  CompressionUtils._();

  /// Compress data if it exceeds the threshold.
  ///
  /// Returns a [CompressedPayload] with the data (possibly compressed)
  /// and metadata about whether compression was applied.
  static CompressedPayload compressIfNeeded(
    String data, {
    int threshold = 1024,
    bool enabled = true,
  }) {
    if (!enabled || kIsWeb) {
      // Web doesn't support dart:io compression
      return CompressedPayload(
        data: utf8.encode(data),
        isCompressed: false,
        originalSize: data.length,
        compressedSize: data.length,
      );
    }

    final bytes = utf8.encode(data);
    if (bytes.length < threshold) {
      return CompressedPayload(
        data: bytes,
        isCompressed: false,
        originalSize: bytes.length,
        compressedSize: bytes.length,
      );
    }

    try {
      final compressed = gzip.encode(bytes);
      final compressionRatio = compressed.length / bytes.length;

      // Only use compression if it actually helps (>10% reduction)
      if (compressionRatio < 0.9) {
        return CompressedPayload(
          data: Uint8List.fromList(compressed),
          isCompressed: true,
          originalSize: bytes.length,
          compressedSize: compressed.length,
        );
      }
    } catch (_) {
      // ignore
    }

    return CompressedPayload(
      data: bytes,
      isCompressed: false,
      originalSize: bytes.length,
      compressedSize: bytes.length,
    );
  }

  /// Compress JSON data if it exceeds the threshold.
  static CompressedPayload compressJson(
    Map<String, dynamic> json, {
    int threshold = 1024,
    bool enabled = true,
  }) {
    final data = jsonEncode(json);
    return compressIfNeeded(data, threshold: threshold, enabled: enabled);
  }

  /// Decompress gzip data.
  static String decompress(Uint8List data) {
    if (kIsWeb) {
      // Web doesn't support dart:io decompression
      return utf8.decode(data);
    }

    try {
      final decompressed = gzip.decode(data);
      return utf8.decode(decompressed);
    } catch (e) {
      // Might not be compressed
      return utf8.decode(data);
    }
  }

  /// Calculate compression ratio for reporting.
  static double getCompressionRatio(
      int originalSize, int compressedSize) {
    if (originalSize == 0) return 1.0;
    return compressedSize / originalSize;
  }

  /// Get human-readable size string.
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Result of compression operation.
@immutable
class CompressedPayload {
  /// The (possibly compressed) data.
  final Uint8List data;

  /// Whether the data was compressed.
  final bool isCompressed;

  /// Original size in bytes.
  final int originalSize;

  /// Compressed size in bytes (same as original if not compressed).
  final int compressedSize;

  const CompressedPayload({
    required this.data,
    required this.isCompressed,
    required this.originalSize,
    required this.compressedSize,
  });

  /// Compression ratio (1.0 = no compression, 0.5 = 50% size reduction).
  double get compressionRatio =>
      originalSize > 0 ? compressedSize / originalSize : 1.0;

  /// Bytes saved by compression.
  int get bytesSaved => originalSize - compressedSize;

  /// Content-Encoding header value if compressed.
  String? get contentEncoding => isCompressed ? 'gzip' : null;

  @override
  String toString() =>
      'CompressedPayload(compressed: $isCompressed, '
      '${CompressionUtils.formatSize(originalSize)} -> '
      '${CompressionUtils.formatSize(compressedSize)}, '
      'ratio: ${(compressionRatio * 100).toStringAsFixed(1)}%)';
}
