import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _certStorage = FlutterSecureStorage();

const String kCertPemKey = 'lm_client_cert_v1';
const String kKeyPemKey = 'lm_client_key_v1';

/// Se lanza cuando no hay certificado de cliente instalado.
class MissingCertException implements Exception {
  const MissingCertException();
  @override
  String toString() => 'MissingCertException: no client certificate installed';
}

class ClientCertPair {
  final Uint8List cert;
  final Uint8List key;
  const ClientCertPair(this.cert, this.key);
}

/// Comprueba que el par forma un SecurityContext valido. Lanza si no.
void validateCertPair(Uint8List certBytes, Uint8List keyBytes) {
  final ctx = SecurityContext(withTrustedRoots: true);
  ctx.useCertificateChainBytes(certBytes);
  ctx.usePrivateKeyBytes(keyBytes);
}

Future<bool> hasClientCert() async {
  try {
    final c = await _certStorage.read(key: kCertPemKey);
    final k = await _certStorage.read(key: kKeyPemKey);
    return c != null && c.isNotEmpty && k != null && k.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> saveClientCert(Uint8List certBytes, Uint8List keyBytes) async {
  validateCertPair(certBytes, keyBytes);
  await _certStorage.write(key: kCertPemKey, value: base64.encode(certBytes));
  await _certStorage.write(key: kKeyPemKey, value: base64.encode(keyBytes));
}

Future<void> deleteClientCert() async {
  await _certStorage.delete(key: kCertPemKey);
  await _certStorage.delete(key: kKeyPemKey);
}

Future<ClientCertPair> loadClientCert() async {
  final c = await _certStorage.read(key: kCertPemKey);
  final k = await _certStorage.read(key: kKeyPemKey);
  if (c == null || c.isEmpty || k == null || k.isEmpty) {
    throw const MissingCertException();
  }
  return ClientCertPair(base64.decode(c), base64.decode(k));
}
