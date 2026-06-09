import 'package:flutter/services.dart';

class NativeWindowService {
  const NativeWindowService();

  static const _channel = MethodChannel('nearsend/native_window');

  Future<void> setMinimizeToTrayEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setMinimizeToTrayEnabled', enabled);
    } on MissingPluginException {
      // Widget tests and non-Windows embedders do not provide this channel.
    }
  }
}
