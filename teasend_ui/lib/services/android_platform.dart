import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper over the `nearsend/android` MethodChannel implemented in
/// MainActivity.kt. All methods are safe no-ops off Android, so callers don't
/// need their own platform guards.
class AndroidPlatform {
  static const _channel = MethodChannel('nearsend/android');

  /// Copies [sourcePath] into the public Downloads/NearSend folder via
  /// MediaStore. Returns a display path on success, or null on failure / when
  /// not on Android.
  static Future<String?> saveToDownloads({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'mimeType': mimeType,
      });
    } catch (_) {
      return null;
    }
  }

  /// Holds a Wi-Fi MulticastLock so the OS stops dropping inbound multicast
  /// packets — required for LocalSend discovery to work on Android.
  static Future<void> acquireMulticastLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('acquireMulticastLock');
    } catch (_) {
      // Discovery still attempts to run even if the lock cannot be acquired.
    }
  }

  static Future<void> releaseMulticastLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('releaseMulticastLock');
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
