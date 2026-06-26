import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nearsend/services/localsend_identity.dart';

void main() {
  test('reuses the persisted certificate identity across restarts', () async {
    SharedPreferences.setMockInitialValues({});

    final first = LocalSendIdentity();
    await first.restorePersistentFingerprint();
    final persisted = first.fingerprint;
    final persistedCertificate = first.securityContext.certificatePem;

    final second = LocalSendIdentity();
    await second.restorePersistentFingerprint();

    expect(second.fingerprint, persisted);
    expect(second.securityContext.certificatePem, persistedCertificate);
    expect(second.fingerprint, second.securityContext.certificateHash);
  });

  test('fingerprint is the certificate hash for HTTPS identity', () async {
    SharedPreferences.setMockInitialValues({});

    final identity = LocalSendIdentity();
    await identity.restorePersistentFingerprint();

    expect(identity.protocol, 'https');
    expect(identity.fingerprint, identity.securityContext.certificateHash);
    expect(identity.fingerprint, isNot('fixed-id'));
  });
}
