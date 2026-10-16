import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  // v217: parser de getsharemsg (invitaciones de comparticion).
  group('parseShareInvitations', () {
    test('lista vacia / data no lista', () {
      expect(parseShareInvitations(null), isEmpty);
      expect(parseShareInvitations({}), isEmpty);
      expect(parseShareInvitations([]), isEmpty);
    });

    test('invitacion completa con permisos', () {
      final list = parseShareInvitations([
        {
          'msgid': 42,
          'shareUserid': 'user-owner-1',
          'carCode': 'LXXXX1234567890',
          'carId': '999',
          'carType': 'c10',
          'carAlias': 'Mi B10',
          'nickName': 'Txurtxil',
          'moduleRights': '100,200,300,400',
          'shareTime': 1690000000000,
        }
      ]);
      expect(list.length, 1);
      final inv = list.first;
      expect(inv.msgId, 42);
      expect(inv.shareUserId, 'user-owner-1');
      expect(inv.vin, 'LXXXX1234567890');
      expect(inv.carAlias, 'Mi B10');
      expect(inv.ownerName, 'Txurtxil');
      expect(inv.hasBasic, isTrue);
      expect(inv.hasVehicleControl, isTrue);
      expect(inv.hasPositioning, isTrue);
      expect(inv.hasMileageEnergy, isTrue);
      expect(inv.shareTime, isNotNull);
    });

    test('tolerante: campos ausentes, msgid como string', () {
      final list = parseShareInvitations([
        {'msgid': '7', 'carCode': 'VIN2', 'moduleRights': '100'}
      ]);
      expect(list.length, 1);
      expect(list.first.msgId, 7);
      expect(list.first.ownerName, '');
      expect(list.first.hasVehicleControl, isFalse);
    });

    test('permisos parciales', () {
      final list = parseShareInvitations([
        {
          'msgid': 3,
          'carCode': 'VIN3',
          'moduleRights': '100,300',
          'email': 'a@b.c'
        }
      ]);
      final inv = list.first;
      expect(inv.hasBasic, isTrue);
      expect(inv.hasVehicleControl, isFalse);
      expect(inv.hasPositioning, isTrue);
      expect(inv.hasMileageEnergy, isFalse);
      expect(inv.ownerName, 'a@b.c');
    });
  });

  group('AC off por modelo (v217)', () {
    test('payload desnudo para la familia C10', () {
      expect(kAcOffPayloadBare, '{"operate":"off"}');
      for (final t in ['b10', 'b11', 'b05', 'c10', 'c11', 'b03']) {
        expect(kBareAcOffCarTypes.contains(t), isTrue, reason: t);
      }
      expect(kBareAcOffCarTypes.contains('B10'.toLowerCase()), isTrue);
    });
  });
}
