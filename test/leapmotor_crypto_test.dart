import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  group('deriveAccountP12Password', () {
    // Vectores cruzados, generados con la libreria Python de referencia
    // (markoceri/leapmotor-api, src/leapmotor_api/crypto.py). Si el port
    // Dart de SM4/MD5/SHA256 se rompe, el login entero deja de funcionar:
    // estos dos vectores lo delatan al instante.
    test('vector cruzado 1', () {
      expect(deriveAccountP12Password('12345678', 'abcdefgh'), '1o0EAFXkvqV6bv/');
    });
    test('vector cruzado 2', () {
      expect(deriveAccountP12Password('987654321', 'LMUSER42'), 'ndRayeDutNzCAOC');
    });
    test('determinista y longitud 15', () {
      final a = deriveAccountP12Password('42', 'x');
      expect(a, deriveAccountP12Password('42', 'x'));
      expect(a.length, 15);
    });
  });

  group('hkdfSha256', () {
    // RFC 5869, Test Case 1 (SHA-256).
    test('vector RFC 5869', () {
      final ikm = Uint8List.fromList(List.filled(22, 0x0b));
      final salt = Uint8List.fromList(
          [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c]);
      final info = Uint8List.fromList(
          [0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9]);
      final okm = hkdfSha256(ikm, salt, info, 42);
      const esperado =
          '3cb25f25faacd57a90434f64d0362f2a'
          '2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
          '34007208d5b887185865';
      final hex = okm.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, esperado);
    });
  });
}
