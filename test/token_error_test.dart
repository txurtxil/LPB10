import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  group('esErrorDeToken', () {
    test('codigo 17 es error de token aunque el mensaje no lo diga', () {
      // Caso real 18/09/2026: mensaje generico sin la palabra token.
      expect(esErrorDeToken(LeapmotorApiException(17, 'session invalid')), isTrue);
      expect(esErrorDeToken(LeapmotorApiException(17, '')), isTrue);
    });

    test('mensaje con token sigue contando', () {
      expect(esErrorDeToken(LeapmotorApiException(0, 'Token expired')), isTrue);
      expect(esErrorDeToken(LeapmotorApiException(-1, 'invalid token')), isTrue);
    });

    test('otros errores no son de token', () {
      expect(esErrorDeToken(LeapmotorApiException(40, 'no rights')), isFalse);
      expect(esErrorDeToken(LeapmotorApiException(500, 'server error')), isFalse);
      expect(esErrorDeToken(LeapmotorApiException(16, 'bad request')), isFalse);
    });
  });

  group('debeBorrarSesion', () {
    test('sesion muerta de verdad: se borra', () {
      expect(debeBorrarSesion(LeapmotorApiException(17, 'session invalid')), isTrue);
      expect(debeBorrarSesion(LeapmotorApiException(0, 'token expired')), isTrue);
    });

    test('errores transitorios NO borran la sesion', () {
      // El caso del reporte 21/09/2026: cortes de red en el arranque
      // borraban la sesion y forzaban login completo cada pocas horas.
      expect(debeBorrarSesion(const SocketException('no network')), isFalse);
      expect(debeBorrarSesion(Exception('Sin vehiculos')), isFalse);
      expect(debeBorrarSesion(LeapmotorApiException(500, 'server error')), isFalse);
      expect(debeBorrarSesion(LeapmotorApiException(40, 'no rights')), isFalse);
      expect(debeBorrarSesion('cualquier cosa'), isFalse);
    });
  });
}
