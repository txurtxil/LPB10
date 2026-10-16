import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

Map<String, dynamic> _respConOta() => {
      'currentVersion': {
        'generalVersion': '1.02.95',
        'time': '1690000000000',
        'logJsonMultiLang': [
          {
            'language': 'it-IT',
            'data': [
              {'title': 'Novita', 'content': 'Migliorie al clima'}
            ]
          }
        ]
      },
      'newVersion': {
        'generalVersion': '1.03.00',
        'state': 1,
        'logJsonMultiLang': [
          {
            'language': 'it-IT',
            'data': [
              {'title': 'Novita', 'content': 'Migliorie'}
            ]
          },
          {
            'language': 'es-ES',
            'data': [
              {'title': 'Novedades', 'content': 'Mejoras del clima'},
              {'title': 'Otros', 'content': 'Errores corregidos'}
            ]
          }
        ],
        'updateItemList': [
          {
            'product': 'IVI',
            'softversion': '1.03.00.100',
            'softNumber': '20260928',
            'hardware': 'H7',
            'fileSize': 1500000000,
            'downloadURL': 'https://secreto/ejemplo',
            'sign': 'no-copiar',
            'md5': 'no-copiar',
          },
          {
            'product': 'TBOX',
            'softversion': '2.01.00',
            'softNumber': '20261001',
            'hardware': 'H2',
            'fileSize': 500000000,
          },
        ],
      },
    };

void main() {
  // v216: parser de hotspot/fetch (versiones de firmware + OTA pendiente).
  group('parseSoftwareInfo', () {
    test('sin OTA pendiente: solo la version instalada', () {
      final info = parseSoftwareInfo({
        'currentVersion': {'generalVersion': '1.02.95', 'time': 1690000000000},
      });
      expect(info.currentVersion, '1.02.95');
      expect(info.updateAvailable, isFalse);
      expect(info.newVersion, '');
      expect(info.packages, isEmpty);
      expect(info.packageCount, 0);
      expect(info.currentInstalledAt, isNotNull);
      expect(info.releaseNotes, isNull);
    });

    test('con OTA: notas en es, paquetes y tamano total', () {
      final info = parseSoftwareInfo(_respConOta());
      expect(info.updateAvailable, isTrue);
      expect(info.newVersion, '1.03.00');
      expect(info.packageCount, 2);
      expect(info.totalBytes, 2000000000);
      expect(info.releaseNotes, contains('Novedades'));
      expect(info.releaseNotes, isNot(contains('Migliorie')));
      expect(info.packages.first.product, 'IVI');
      expect(info.packages.first.sizeLabel, isNotEmpty);
    });

    test('fallback de idioma: fr cae al primero disponible', () {
      final info = parseSoftwareInfo(_respConOta(), language: 'fr');
      expect(info.releaseNotes, contains('Novita'));
    });

    test('los secretos (downloadURL/sign/md5) nunca entran en el modelo', () {
      final info = parseSoftwareInfo(_respConOta());
      expect(info.toString(), isNot(contains('https://secreto')));
      expect(info.toString(), isNot(contains('no-copiar')));
    });

    test('formatBytes: unidades humanas', () {
      expect(SoftwareInfo.formatBytes(0), '0 B');
      expect(SoftwareInfo.formatBytes(512), '512 B');
      expect(SoftwareInfo.formatBytes(2048), '2.0 kB');
      expect(SoftwareInfo.formatBytes(1500000000), '1.4 GB');
    });
  });
}
