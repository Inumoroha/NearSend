import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nearsend/services/localsend_identity.dart';

void main() {
  test('reuses the persisted fingerprint across restarts', () async {
    SharedPreferences.setMockInitialValues({});

    final first = LocalSendIdentity();
    await first.restorePersistentFingerprint();
    final persisted = first.fingerprint;

    // A fresh identity simulates a relaunch (it generates a new random value),
    // but restore must pin it back to the persisted one so the device keeps a
    // single identity instead of appearing as a new peer each launch.
    final second = LocalSendIdentity();
    await second.restorePersistentFingerprint();

    expect(second.fingerprint, persisted);
  });

  test('a stored fingerprint overrides the freshly generated one', () async {
    SharedPreferences.setMockInitialValues({'device_fingerprint': 'fixed-id'});

    final identity = LocalSendIdentity();
    await identity.restorePersistentFingerprint();

    expect(identity.fingerprint, 'fixed-id');
  });
}
