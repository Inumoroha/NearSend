import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// 临时文件清理服务
///
/// 管理应用创建的临时文件，提供定期清理和手动清理功能。
class TempFileCleanupService {
  TempFileCleanupService({required SharedPreferences preferences})
      : _preferences = preferences {
    _loadSettings();
  }

  final SharedPreferences _preferences;
  Timer? _cleanupTimer;

  // 临时文件目录前缀
  static const List<String> _tempDirPrefixes = [
    'nearsend_incoming_',
    'nearsend_localsend_',
    'nearsend_clipboard_',
  ];

  // 设置键
  static const String _autoCleanupEnabledKey = 'temp_auto_cleanup_enabled';
  static const String _cleanupOlderThanDaysKey = 'temp_cleanup_older_than_days';
  static const String _cleanupOnStartupKey = 'temp_cleanup_on_startup';

  // 默认值
  static const bool _defaultAutoCleanupEnabled = true;
  static const int _defaultCleanupOlderThanDays = 7; // 7天
  static const bool _defaultCleanupOnStartup = true;

  // 当前设置
  bool _autoCleanupEnabled = _defaultAutoCleanupEnabled;
  int _cleanupOlderThanDays = _defaultCleanupOlderThanDays;
  bool _cleanupOnStartup = _defaultCleanupOnStartup;

  /// 是否启用自动清理
  bool get autoCleanupEnabled => _autoCleanupEnabled;

  /// 清理超过多少天的文件
  int get cleanupOlderThanDays => _cleanupOlderThanDays;

  /// 是否在启动时清理
  bool get cleanupOnStartup => _cleanupOnStartup;

  /// 已清理的文件数量（最后一次清理）
  int _lastCleanupFiles = 0;

  /// 释放的磁盘空间（字节）（最后一次清理）
  int _lastCleanupBytes = 0;

  int get lastCleanupFiles => _lastCleanupFiles;
  int get lastCleanupBytes => _lastCleanupBytes;

  /// 从 SharedPreferences 加载设置
  Future<void> _loadSettings() async {
    _autoCleanupEnabled = _preferences.getBool(_autoCleanupEnabledKey) ??
        _defaultAutoCleanupEnabled;
    _cleanupOlderThanDays =
        _preferences.getInt(_cleanupOlderThanDaysKey) ??
            _defaultCleanupOlderThanDays;
    _cleanupOnStartup = _preferences.getBool(_cleanupOnStartupKey) ??
        _defaultCleanupOnStartup;

    if (_autoCleanupEnabled) {
      _startPeriodicCleanup();
    }
  }

  /// 启动定期清理（每小时检查一次）
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => performCleanupIfNeeded(),
    );
  }

  /// 停止定期清理
  void _stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// 设置是否启用自动清理
  Future<void> setAutoCleanupEnabled(bool enabled) async {
    _autoCleanupEnabled = enabled;
    await _preferences.setBool(_autoCleanupEnabledKey, enabled);

    if (enabled) {
      _startPeriodicCleanup();
    } else {
      _stopPeriodicCleanup();
    }
  }

  /// 设置清理超过多少天的文件
  Future<void> setCleanupOlderThanDays(int days) async {
    _cleanupOlderThanDays = days.clamp(1, 365);
    await _preferences.setInt(_cleanupOlderThanDaysKey, _cleanupOlderThanDays);
  }

  /// 设置是否在启动时清理
  Future<void> setCleanupOnStartup(bool enabled) async {
    _cleanupOnStartup = enabled;
    await _preferences.setBool(_cleanupOnStartupKey, enabled);
  }

  /// 执行启动时的清理（如果启用）
  Future<void> performStartupCleanup() async {
    if (_cleanupOnStartup) {
      await performCleanup();
    }
  }

  /// 执行清理（如果需要）
  /// 根据当前设置判断是否需要清理
  Future<void> performCleanupIfNeeded() async {
    if (!_autoCleanupEnabled) return;

    final lastCleanup = _preferences.getInt('temp_last_cleanup_timestamp');
    if (lastCleanup == null) {
      await performCleanup();
      return;
    }

    // 每天至少清理一次
    final lastCleanupTime = DateTime.fromMillisecondsSinceEpoch(lastCleanup);
    final now = DateTime.now();
    if (now.difference(lastCleanupTime).inDays >= 1) {
      await performCleanup();
    }
  }

  /// 执行清理
  /// 返回清理的文件数量和释放的空间
  Future<CleanupResult> performCleanup() async {
    _lastCleanupFiles = 0;
    _lastCleanupBytes = 0;
    final cutoffTime = DateTime.now().subtract(
      Duration(days: _cleanupOlderThanDays),
    );

    try {
      final systemTempDir = Directory.systemTemp;

      // 查找所有临时文件目录
      final tempDirs = <Directory>[];
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (_tempDirPrefixes.any((prefix) => name.startsWith(prefix))) {
            tempDirs.add(entity);
          }
        }
      }

      // 清理每个临时目录中的文件
      for (final tempDir in tempDirs) {
        await _cleanupDirectory(tempDir, cutoffTime);

        // 如果目录为空，删除目录本身
        try {
          if (await tempDir.list().isEmpty) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {
          // 忽略删除失败
        }
      }

      // 记录清理时间
      await _preferences.setInt(
        'temp_last_cleanup_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      return CleanupResult(
        filesCleaned: _lastCleanupFiles,
        bytesFreed: _lastCleanupBytes,
        success: true,
      );
    } catch (e) {
      return CleanupResult(
        filesCleaned: _lastCleanupFiles,
        bytesFreed: _lastCleanupBytes,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 清理指定目录中的过期文件
  Future<void> _cleanupDirectory(
    Directory dir,
    DateTime cutoffTime,
  ) async {
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            final modified = stat.modified;

            if (modified.isBefore(cutoffTime)) {
              final size = await entity.length();
              await entity.delete();
              _lastCleanupFiles++;
              _lastCleanupBytes += size;
            }
          } catch (_) {
            // 文件可能已被删除，忽略
          }
        }
      }
    } catch (_) {
      // 目录访问失败，忽略
    }
  }

  /// 获取当前临时文件使用情况
  Future<TempFileUsage> getTempFileUsage() async {
    int totalFiles = 0;
    int totalBytes = 0;
    int oldFiles = 0;
    int oldBytes = 0;

    final cutoffTime = DateTime.now().subtract(
      Duration(days: _cleanupOlderThanDays),
    );

    try {
      final systemTempDir = Directory.systemTemp;

      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (_tempDirPrefixes.any((prefix) => name.startsWith(prefix))) {
            await for (final file in entity.list(recursive: true)) {
              if (file is File) {
                try {
                  final stat = await file.stat();
                  final size = await file.length();
                  totalFiles++;
                  totalBytes += size;

                  if (stat.modified.isBefore(cutoffTime)) {
                    oldFiles++;
                    oldBytes += size;
                  }
                } catch (_) {
                  // 文件可能已被删除，忽略
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // 访问失败，返回零值
    }

    return TempFileUsage(
      totalFiles: totalFiles,
      totalBytes: totalBytes,
      oldFiles: oldFiles,
      oldBytes: oldBytes,
    );
  }

  /// 手动清理所有临时文件（忽略时间限制）
  Future<CleanupResult> performFullCleanup() async {
    _lastCleanupFiles = 0;
    _lastCleanupBytes = 0;

    try {
      final systemTempDir = Directory.systemTemp;

      // 查找并删除所有临时文件目录
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (_tempDirPrefixes.any((prefix) => name.startsWith(prefix))) {
            try {
              // 统计文件数量和大小
              await for (final file in entity.list(recursive: true)) {
                if (file is File) {
                  try {
                    final size = await file.length();
                    _lastCleanupFiles++;
                    _lastCleanupBytes += size;
                  } catch (_) {}
                }
              }

              // 删除整个目录
              await entity.delete(recursive: true);
            } catch (_) {
              // 删除失败，忽略
            }
          }
        }
      }

      // 记录清理时间
      await _preferences.setInt(
        'temp_last_cleanup_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      return CleanupResult(
        filesCleaned: _lastCleanupFiles,
        bytesFreed: _lastCleanupBytes,
        success: true,
      );
    } catch (e) {
      return CleanupResult(
        filesCleaned: _lastCleanupFiles,
        bytesFreed: _lastCleanupBytes,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 释放资源
  void dispose() {
    _stopPeriodicCleanup();
  }
}

/// 清理结果
class CleanupResult {
  const CleanupResult({
    required this.filesCleaned,
    required this.bytesFreed,
    required this.success,
    this.error,
  });

  final int filesCleaned;
  final int bytesFreed;
  final bool success;
  final String? error;
}

/// 临时文件使用情况
class TempFileUsage {
  const TempFileUsage({
    required this.totalFiles,
    required this.totalBytes,
    required this.oldFiles,
    required this.oldBytes,
  });

  final int totalFiles;
  final int totalBytes;
  final int oldFiles;
  final int oldBytes;
}

/// 格式化字节大小
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final digits = index == 0 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[index]}';
}
