import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

class LocalSendSecurityContext {
  const LocalSendSecurityContext({
    required this.privateKeyPem,
    required this.publicKeyPem,
    required this.certificatePem,
    required this.certificateHash,
  });

  final String privateKeyPem;
  final String publicKeyPem;
  final String certificatePem;
  final String certificateHash;

  SecurityContext toServerSecurityContext() {
    return SecurityContext()
      ..usePrivateKeyBytes(utf8.encode(privateKeyPem))
      ..useCertificateChainBytes(utf8.encode(certificatePem));
  }

  Map<String, String> toJson() {
    return {
      'privateKey': privateKeyPem,
      'publicKey': publicKeyPem,
      'certificate': certificatePem,
      'certificateHash': certificateHash,
    };
  }

  static LocalSendSecurityContext? fromJson(Map<String, Object?> json) {
    final privateKey = json['privateKey'];
    final publicKey = json['publicKey'];
    final certificate = json['certificate'];
    final certificateHash = json['certificateHash'];
    if (privateKey is! String ||
        publicKey is! String ||
        certificate is! String ||
        certificateHash is! String) {
      return null;
    }

    final normalizedCertificate = normalizeCertificateHash(
      calculateCertificateHash(certificate),
    );
    if (normalizedCertificate != normalizeCertificateHash(certificateHash)) {
      return null;
    }

    return LocalSendSecurityContext(
      privateKeyPem: privateKey,
      publicKeyPem: publicKey,
      certificatePem: certificate,
      certificateHash: normalizedCertificate,
    );
  }
}

LocalSendSecurityContext generateLocalSendSecurityContext() {
  final keyPair = CryptoUtils.generateRSAKeyPair();
  final privateKey = keyPair.privateKey as RSAPrivateKey;
  final publicKey = keyPair.publicKey as RSAPublicKey;
  final csr = X509Utils.generateRsaCsrPem(
    const {
      'CN': 'NearSend User',
      'O': 'NearSend',
      'OU': '',
      'L': '',
      'S': '',
      'C': '',
    },
    privateKey,
    publicKey,
  );
  final certificate = X509Utils.generateSelfSignedCertificate(
    privateKey,
    csr,
    365 * 10,
  );

  final publicKeyPem = X509Utils.fixPem('''-----BEGIN PUBLIC KEY-----
${base64Encode(_subjectPublicKeyInfo(certificate))}
-----END PUBLIC KEY-----''');

  return LocalSendSecurityContext(
    privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey),
    publicKeyPem: publicKeyPem,
    certificatePem: certificate,
    certificateHash: calculateCertificateHash(certificate),
  );
}

String certificateHashFromX509(X509Certificate certificate) {
  return CryptoUtils.getHash(certificate.der, algorithmName: 'SHA-256');
}

String calculateCertificateHash(String certificatePem) {
  return CryptoUtils.getHash(
    Uint8List.fromList(_certificateDerFromPem(certificatePem)),
    algorithmName: 'SHA-256',
  );
}

String normalizeCertificateHash(String hash) {
  return hash.replaceAll(':', '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
}

HttpClient createLocalSendHttpClient({
  required String? trustedFingerprint,
  Duration? connectionTimeout,
  void Function(String certificateHash)? onPeerCertificate,
}) {
  final normalizedTrusted = trustedFingerprint == null
      ? null
      : normalizeCertificateHash(trustedFingerprint);
  final client = HttpClient();
  if (connectionTimeout != null) {
    client.connectionTimeout = connectionTimeout;
  }
  client.badCertificateCallback = (certificate, host, port) {
    final hash = certificateHashFromX509(certificate);
    onPeerCertificate?.call(hash);
    if (normalizedTrusted == null || normalizedTrusted.isEmpty) {
      return true;
    }
    return normalizeCertificateHash(hash) == normalizedTrusted;
  };
  return client;
}

void ensurePeerCertificateMatches({
  required Uri uri,
  required String? expectedFingerprint,
  required String? observedFingerprint,
}) {
  if (uri.scheme != 'https') return;
  if (expectedFingerprint == null || expectedFingerprint.isEmpty) return;
  if (observedFingerprint == null || observedFingerprint.isEmpty) {
    throw const TlsFingerprintException('Missing peer certificate');
  }
  if (normalizeCertificateHash(expectedFingerprint) !=
      normalizeCertificateHash(observedFingerprint)) {
    throw const TlsFingerprintException('Peer certificate does not match');
  }
}

void ensureResponseCertificateMatches({
  required Uri uri,
  required String? expectedFingerprint,
  required HttpClientResponse response,
}) {
  ensurePeerCertificateMatches(
    uri: uri,
    expectedFingerprint: expectedFingerprint,
    observedFingerprint: response.certificate == null
        ? null
        : certificateHashFromX509(response.certificate!),
  );
}

List<int> _certificateDerFromPem(String certificatePem) {
  final pemContent = certificatePem
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((line) => line.isNotEmpty && !line.startsWith('---'))
      .join();
  return base64Decode(pemContent);
}

List<int> _subjectPublicKeyInfo(String certificatePem) {
  final certificate = X509Utils.x509CertificateFromPem(certificatePem);
  final hex = certificate.tbsCertificate!.subjectPublicKeyInfo.bytes!;
  final bytes = <int>[];
  for (var index = 0; index < hex.length; index += 2) {
    bytes.add(int.parse(hex.substring(index, index + 2), radix: 16));
  }
  return bytes;
}

class TlsFingerprintException implements Exception {
  const TlsFingerprintException(this.message);

  final String message;

  @override
  String toString() => message;
}
