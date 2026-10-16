import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  // v218: endpoints owner-side de comparticion (descubrimiento via carlog).
  group('buildShareInviteParams', () {
    test('campos y valores por defecto', () {
      final p = buildShareInviteParams(
          vin: 'VIN1', userId: 'U1', invitee: 'a@b.c');
      expect(p['carCode'], 'VIN1');
      expect(p['userId'], 'U1');
      expect(p['email'], 'a@b.c');
      expect(p['moduleRights'], '100,200,300,400');
      expect(p['durationType'], '0');
    });

    test('permisos y duracion personalizados', () {
      final p = buildShareInviteParams(
          vin: 'V', userId: 'U', invitee: 'x@y.z',
          moduleRights: '100', durationType: 7);
      expect(p['moduleRights'], '100');
      expect(p['durationType'], '7');
    });
  });

  group('buildShareRevokeParams', () {
    test('campos', () {
      final p = buildShareRevokeParams(
          vin: 'VIN2', userId: 'U2', shareUserId: 'S3');
      expect(p['carCode'], 'VIN2');
      expect(p['userId'], 'U2');
      expect(p['shareUserId'], 'S3');
    });
  });

  group('parseSharedUsers', () {
    test('vacio / no lista', () {
      expect(parseSharedUsers(null), isEmpty);
      expect(parseSharedUsers('x'), isEmpty);
    });

    test('entrada completa con permisos', () {
      final list = parseSharedUsers([
        {
          'shareUserid': 'S1',
          'nickName': 'Beta',
          'email': 'b@c.d',
          'mobileNumber': '600000000',
          'moduleRights': '100,200',
          'expireTime': 1690000000000,
        }
      ]);
      expect(list.length, 1);
      final u = list.first;
      expect(u.shareUserId, 'S1');
      expect(u.displayName, 'Beta');
      expect(u.hasVehicleControl, isTrue);
      expect(u.hasPositioning, isFalse);
    });

    test('variantes de nombres de campos', () {
      final list = parseSharedUsers([
        {'shareUserId': 'S9', 'userId': 'ignored', 'email': 'e@f.g'}
      ]);
      expect(list.first.shareUserId, 'S9');
      expect(list.first.nickName, '');
      expect(list.first.displayName, 'e@f.g');
    });
  });
}

