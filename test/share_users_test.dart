import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  // v218: endpoints owner-side de comparticion (descubrimiento via carlog).
  group('buildShareRevokeParams', () {
    test('campos', () {
      final p = buildShareRevokeParams(
          vin: 'VIN2', userId: 'U2', shareUserId: 'S3');
      expect(p['carcode'], 'VIN2');
      expect(p['userid'], 'U2');
      expect(p['shareuserid'], 'S3');
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
          'shareuserid': 'S1',
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
        {'shareuserid': 'S9', 'userid': 'ignored', 'email': 'e@f.g'}
      ]);
      expect(list.first.shareUserId, 'S9');
      expect(list.first.nickName, '');
      expect(list.first.displayName, 'e@f.g');
    });
  });
}

