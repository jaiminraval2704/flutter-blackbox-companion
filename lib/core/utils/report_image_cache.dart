import 'dart:convert';
import 'package:flutter/services.dart';

/// In-memory cache for decoded report screenshot bytes.
///
/// Prevents base64 re-decoding and Image.memory flickering on every rebuild.
class ReportImageCache {
  static final Map<String, Uint8List> _cache = {};

  /// Retrieves cached Uint8List bytes or decodes and caches from base64 string.
  static Uint8List? getBytes(String key, String base64Str) {
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(base64Str);
      _cache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Clears the image cache.
  static void clear() {
    _cache.clear();
  }
}
