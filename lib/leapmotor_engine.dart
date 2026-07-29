import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/io_client.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'car_log_bridge.dart';
import 'cert_store.dart';

// ============================================================
// Constantes reales, extraídas de leapmotor_api/const.py (pip)
// ============================================================
const String kBaseUrl = 'https://appgateway.leapmotor-international.de';
const String kAppVersion = '1.12.3';
const String kChannel = '1';
const String kDeviceType = '1';
const String kLanguage = 'en-GB';
const String kSource = 'leapmotor';
const String kP12EncAlg = '1';
const String kPolicyId = '20260204';
const String kOperpwdAesKey = 'f1cf0c025baec0e2';
const String kOperpwdAesIv = '6b6a1fe94e133fd7';

// ============================================================
// SM4 (tablas y claves de ronda fijas, de leapmotor_api/crypto.py)
// ============================================================
const List<int> _sm4Sbox = [
  0xD6, 0x90, 0xE9, 0xFE, 0xCC, 0xE1, 0x3D, 0xB7, 0x16, 0xB6, 0x14, 0xC2, 0x28, 0xFB, 0x2C, 0x05,
  0x2B, 0x67, 0x9A, 0x76, 0x2A, 0xBE, 0x04, 0xC3, 0xAA, 0x44, 0x13, 0x26, 0x49, 0x86, 0x06, 0x99,
  0x9C, 0x42, 0x50, 0xF4, 0x91, 0xEF, 0x98, 0x7A, 0x33, 0x54, 0x0B, 0x43, 0xED, 0xCF, 0xAC, 0x62,
  0xE4, 0xB3, 0x1C, 0xA9, 0xC9, 0x08, 0xE8, 0x95, 0x80, 0xDF, 0x94, 0xFA, 0x75, 0x8F, 0x3F, 0xA6,
  0x47, 0x07, 0xA7, 0xFC, 0xF3, 0x73, 0x17, 0xBA, 0x83, 0x59, 0x3C, 0x19, 0xE6, 0x85, 0x4F, 0xA8,
  0x68, 0x6B, 0x81, 0xB2, 0x71, 0x64, 0xDA, 0x8B, 0xF8, 0xEB, 0x0F, 0x4B, 0x70, 0x56, 0x9D, 0x35,
  0x1E, 0x24, 0x0E, 0x5E, 0x63, 0x58, 0xD1, 0xA2, 0x25, 0x22, 0x7C, 0x3B, 0x01, 0x21, 0x78, 0x87,
  0xD4, 0x00, 0x46, 0x57, 0x9F, 0xD3, 0x27, 0x52, 0x4C, 0x36, 0x02, 0xE7, 0xA0, 0xC4, 0xC8, 0x9E,
  0xEA, 0xBF, 0x8A, 0xD2, 0x40, 0xC7, 0x38, 0xB5, 0xA3, 0xF7, 0xF2, 0xCE, 0xF9, 0x61, 0x15, 0xA1,
  0xE0, 0xAE, 0x5D, 0xA4, 0x9B, 0x34, 0x1A, 0x55, 0xAD, 0x93, 0x32, 0x30, 0xF5, 0x8C, 0xB1, 0xE3,
  0x1D, 0xF6, 0xE2, 0x2E, 0x82, 0x66, 0xCA, 0x60, 0xC0, 0x29, 0x23, 0xAB, 0x0D, 0x53, 0x4E, 0x6F,
  0xD5, 0xDB, 0x37, 0x45, 0xDE, 0xFD, 0x8E, 0x2F, 0x03, 0xFF, 0x6A, 0x72, 0x6D, 0x6C, 0x5B, 0x51,
  0x8D, 0x1B, 0xAF, 0x92, 0xBB, 0xDD, 0xBC, 0x7F, 0x11, 0xD9, 0x5C, 0x41, 0x1F, 0x10, 0x5A, 0xD8,
  0x0A, 0xC1, 0x31, 0x88, 0xA5, 0xCD, 0x7B, 0xBD, 0x2D, 0x74, 0xD0, 0x12, 0xB8, 0xE5, 0xB4, 0xB0,
  0x89, 0x69, 0x97, 0x4A, 0x0C, 0x96, 0x77, 0x7E, 0x65, 0xB9, 0xF1, 0x09, 0xC5, 0x6E, 0xC6, 0x84,
  0x18, 0xF0, 0x7D, 0xEC, 0x3A, 0xDC, 0x4D, 0x20, 0x79, 0xEE, 0x5F, 0x3E, 0xD7, 0xCB, 0x39, 0x48,
];

const List<int> _p12Sm4RoundKeys = [
  0x818FA553, 0xEBA3318D, 0x5FC3C93A, 0xBD1DADD9,
  0xBB61CAB9, 0x000FD7EA, 0xDC6E0166, 0xDA937279,
  0x607EE786, 0xB548754C, 0x107330E4, 0xEA17C186,
  0x0F56F74B, 0xB21E443C, 0xE1210FE2, 0x009995C8,
  0xE7529A48, 0x6EF474F6, 0x2AB06DF6, 0x43B11BE8,
  0x359D4A14, 0xC29E2CDE, 0x30CF6A3E, 0x79D1C806,
  0x7C502387, 0xAAAB9BC6, 0xF0FE744B, 0x1CAFC872,
  0x95A9D075, 0x88070D58, 0x22800475, 0x8391938B,
];

int _rotl32(int v, int bits) {
  v &= 0xFFFFFFFF;
  return ((v << bits) | (v >> (32 - bits))) & 0xFFFFFFFF;
}

int _u32be(Uint8List b, int offset) =>
    (b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3];

void _writeU32be(BytesBuilder out, int value) {
  out.add([(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]);
}

Uint8List _sm4EncryptBlock(Uint8List block) {
  int x0 = _u32be(block, 0), x1 = _u32be(block, 4), x2 = _u32be(block, 8), x3 = _u32be(block, 12);
  for (final roundKey in _p12Sm4RoundKeys) {
    final t = (x1 ^ x2 ^ x3 ^ roundKey) & 0xFFFFFFFF;
    final b = ((_sm4Sbox[(t >> 24) & 0xFF] << 24) |
            (_sm4Sbox[(t >> 16) & 0xFF] << 16) |
            (_sm4Sbox[(t >> 8) & 0xFF] << 8) |
            _sm4Sbox[t & 0xFF]) &
        0xFFFFFFFF;
    final newX = (x0 ^ b ^ _rotl32(b, 2) ^ _rotl32(b, 10) ^ _rotl32(b, 18) ^ _rotl32(b, 24)) & 0xFFFFFFFF;
    x0 = x1; x1 = x2; x2 = x3; x3 = newX;
  }
  final out = BytesBuilder();
  _writeU32be(out, x3); _writeU32be(out, x2); _writeU32be(out, x1); _writeU32be(out, x0);
  return out.toBytes();
}

Uint8List _p12MemoryEncode(Uint8List data) {
  final padLen = 16 - (data.length % 16);
  final padded = Uint8List(data.length + padLen);
  padded.setRange(0, data.length, data);
  for (int i = data.length; i < padded.length; i++) {
    padded[i] = padLen;
  }
  final out = BytesBuilder();
  for (int offset = 0; offset < padded.length; offset += 16) {
    out.add(_sm4EncryptBlock(padded.sublist(offset, offset + 16)));
  }
  return out.toBytes();
}

String _everyNth(String s, int step, int start) {
  final buf = StringBuffer();
  for (int i = start; i < s.length; i += step) {
    buf.write(s[i]);
  }
  return buf.toString();
}

String deriveAccountP12Password(String accountId, String uid) {
  final cn = crypto.md5.convert(ascii.encode(accountId)).toString();
  final cnEven = _everyNth(cn, 2, 0);
  final uidOdd = _everyNth(uid, 2, 1);
  final digest = crypto.sha256.convert(ascii.encode('$cn$cnEven$uidOdd')).bytes;
  final encoded = _p12MemoryEncode(Uint8List.fromList(digest));
  final b64 = base64.encode(encoded.sublist(0, 12));
  return b64.substring(0, b64.length < 15 ? b64.length : 15);
}

Uint8List hkdfSha256(Uint8List ikm, Uint8List salt, Uint8List info, int length) {
  final hmac = crypto.Hmac(crypto.sha256, salt.isEmpty ? Uint8List(32) : salt);
  final prk = hmac.convert(ikm).bytes;
  final t = <int>[];
  int blockIndex = 1;
  while (t.length < length) {
    final tBlock = crypto.Hmac(crypto.sha256, prk).convert(Uint8List.fromList([...t, ...info, blockIndex])).bytes;
    t.addAll(tBlock);
    blockIndex++;
  }
  return Uint8List.fromList(t.sublist(0, length));
}

String deriveSessionDeviceId(String? token, String fallbackDeviceId) {
  if (token == null || token.isEmpty) return fallbackDeviceId;
  try {
    final parts = token.split('.');
    if (parts.length < 2) return fallbackDeviceId;
    var payloadB64 = parts[1];
    payloadB64 += '=' * ((4 - payloadB64.length % 4) % 4);
    final payload = json.decode(utf8.decode(base64Url.decode(payloadB64))) as Map<String, dynamic>;
    final userName = (payload['user_name'] ?? '').toString();
    final segments = userName.split(',');
    if (segments.length >= 4 && segments[2].isNotEmpty) return segments[2];
  } catch (_) {}
  return fallbackDeviceId;
}

(String, String) deriveOperpwdKeyIv(String? token) {
  if (token == null || token.length < 64) {
    return (kOperpwdAesKey, kOperpwdAesIv);
  }
  final keySource = token.substring(0, 32);
  final ivSource = token.substring(32, 64);
  final keyText = crypto.md5.convert(utf8.encode(keySource)).toString().substring(8, 24);
  final ivText = crypto.md5.convert(utf8.encode(ivSource)).toString().substring(8, 24);
  return (keyText, ivText);
}

Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
  final padLen = blockSize - (data.length % blockSize);
  final padded = Uint8List(data.length + padLen);
  padded.setRange(0, data.length, data);
  for (int i = data.length; i < padded.length; i++) {
    padded[i] = padLen;
  }
  return padded;
}

String encryptOperatePassword(String pin, String? token) {
  final (keyText, ivText) = deriveOperpwdKeyIv(token);
  final keyBytes = Uint8List.fromList(utf8.encode(keyText));
  final ivBytes = Uint8List.fromList(utf8.encode(ivText));
  final padded = _pkcs7Pad(Uint8List.fromList(utf8.encode(pin)), 16);
  final cipher = pc.CBCBlockCipher(pc.AESEngine())
    ..init(true, pc.ParametersWithIV(pc.KeyParameter(keyBytes), ivBytes));
  final output = Uint8List(padded.length);
  for (int offset = 0; offset < padded.length; offset += 16) {
    cipher.processBlock(padded, offset, output, offset);
  }
  return base64.encode(output);
}

const Map<String, String> kSignalToNamed = {
  '47': 'acInputSlowCharge', '1204': 'soc', '100003': 'preciseSoc', '1200': 'chargeRemainTime',
  '1178': 'batteryCurrent', '1177': 'batteryVoltage', '1197': 'dcInputFastCharge', '1149': 'chargeState',
  '1182': 'minBatteryTemp', '1186': 'batteryThermalRequest', '3736': 'chargeCompleted', '48': 'healthyChargeEnabled',
  '3260': 'expectedMileage', '2188': 'liveRemainingRange', '3257': 'maxRange', '3262': 'rangeMode',
  '1319': 'speed', '1318': 'totalMileage', '1010': 'gearStatus', '1944': 'vehicleState',
  '1480': 'parkingBrakeState', '6048': 'speedLimit', '6047': 'speedLimitUnit', '12054': 'speedLimitActive',
  '1938': 'acSwitch', '2183': 'acSetting', '2184': 'acSettingRight', '1349': 'interiorTemp',
  '1943': 'recirculationMode', '1945': 'windshieldDefrost', '1946': 'rearWindowHeating', '3713': 'climateMode',
  '2669': 'rapidCooling', '2681': 'rapidHeating', '1939': 'acOperateMode', '1941': 'acAirVolume',
  '1298': 'driverDoorLockStatus', '1277': 'lbcmDriverDoorStatus', '1278': 'rbcmDriverDoorStatus',
  '1279': 'lbcmLeftRearDoorStatus', '1280': 'rbcmRightRearDoorStatus', '1281': 'bbcmBackDoorStatus',
  '1256': 'bcmKeyPositionOn1', '1257': 'bcmKeyPositionOn2', '1258': 'bcmKeyPositionOn3',
  '2100': 'driverSeatHeating', '2101': 'driverSeatVentilation', '2118': 'passengerSeatHeating',
  '2119': 'passengerSeatVentilation', '1816': 'steeringWheelHeating', '1624': 'steeringWheelHeaterMinutes',
  '1255': 'vehicleSecurityActive', '3636': 'sentryMode', '49': 'leftMirrorHeating', '50': 'rightMirrorHeating',
  '1724': 'roofOpening',
  '2667': 'leftFrontTirePressure',
  '2653': 'rightFrontTirePressure',
  '2646': 'leftRearTirePressure',
  '2660': 'rightRearTirePressure',
  '2641': 'leftFrontTirePressureState',
  '2648': 'rightFrontTirePressureState',
  '2655': 'leftRearTirePressureState',
  '2662': 'rightRearTirePressureState',
};

Map<String, dynamic> mergeSignalToNamed(Map<String, dynamic> statusData) {
  final signal = statusData['signal'];
  if (signal is! Map) return statusData;
  final merged = Map<String, dynamic>.from(statusData);
  kSignalToNamed.forEach((signalId, namedField) {
    if (signal.containsKey(signalId) && !merged.containsKey(namedField)) {
      merged[namedField] = signal[signalId];
    }
  });
  // El backend manda las senales 3724/2191 y 3725/2190 en VALOR ABSOLUTO.
  // Verificado en el snapshot del 29/07: senal 2 = -2.987649 y senal 3724 =
  // 2.987649, el mismo numero hasta el ultimo decimal, sin signo. En longitud
  // oeste (toda Espana) tirar de un fallback situaria el coche en el hemisferio
  // equivocado, a unos 500 km de distancia.
  //
  // No se corrige nada a proposito: el signo correcto no se puede deducir del
  // propio snapshot cuando falta la senal 2, haria falta la ultima posicion
  // conocida y esta funcion es pura. La senal 2 va primera y hasta hoy nunca ha
  // faltado. Se deja traza para saber si eso llega a pasar alguna vez; si el
  // log nunca lo registra, no hay nada que arreglar.
  if (!merged.containsKey('longitude')) {
    for (final lonSignal in ['2', '3724', '2191']) {
      if (signal.containsKey(lonSignal)) {
        merged['longitude'] = signal[lonSignal];
        if (lonSignal != '2') {
          CarLogBridge.log('GPS lon por fallback senal ' + lonSignal +
              ' = ' + signal[lonSignal].toString() + ' (signo NO fiable)');
        }
        break;
      }
    }
  }
  if (!merged.containsKey('latitude')) {
    for (final latSignal in ['3', '3725', '2190']) {
      if (signal.containsKey(latSignal)) {
        merged['latitude'] = signal[latSignal];
        if (latSignal != '3') {
          CarLogBridge.log('GPS lat por fallback senal ' + latSignal +
              ' = ' + signal[latSignal].toString());
        }
        break;
      }
    }
  }
  return merged;
}

double? _asDouble(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int? _asInt(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
bool? _asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  return v.toString() == '1' || v.toString().toLowerCase() == 'true';
}

class VehicleStatus {
  final int? soc;
  final double? preciseSoc;
  final int? chargeState;
  final bool? acInputSlowCharge;
  final bool? dcInputFastCharge;
  final int? batteryThermalRequest;
  final int? liveRemainingRange;
  final double? latitude;
  final double? longitude;
  final bool? acSwitch;
  final bool? driverDoorLockStatus;
  final bool? bbcmBackDoorStatus;
  final int? sentryMode;
  final int? totalMileage;
  final double? speed;
  final bool? chargeCompleted;
  final int? leftFrontTireKpa;
  final int? rightFrontTireKpa;
  final int? leftRearTireKpa;
  final int? rightRearTireKpa;
  final Map<String, dynamic> raw;

  VehicleStatus({
    this.soc, this.preciseSoc, this.chargeState, this.acInputSlowCharge, this.dcInputFastCharge,
    this.batteryThermalRequest, this.liveRemainingRange, this.latitude, this.longitude, this.acSwitch,
    this.driverDoorLockStatus, this.bbcmBackDoorStatus, this.sentryMode, this.totalMileage,
    this.speed, this.chargeCompleted,
    this.leftFrontTireKpa, this.rightFrontTireKpa, this.leftRearTireKpa, this.rightRearTireKpa,
    required this.raw,
  });

  int? get chargeLimitPercent {
    final config = raw['config'];
    if (config is! Map) return null;
    for (final v in config.values) {
      if (v is Map && v.containsKey('percent') && v.containsKey('cycles')) {
        final p = v['percent'];
        if (p is num) return p.toInt();
      }
    }
    return null;
  }

  bool get isLocked => driverDoorLockStatus ?? false;
  /// Cargando de verdad: chargeState activo Y enchufado Y carga no
  /// completada. chargeState != 0 tambien se da con la regeneracion al
  /// conducir y con la carga terminada: causaba falsos "Cargando" y
  /// sesiones fantasma en el historial.
  bool get isCharging =>
      (chargeState ?? 0) != 0 &&
      isPluggedIn &&
      (chargeCompleted != true);
  /// Ruedas con estado de presion anomalo (no normal). Lee los *PressureState
  /// del raw. Convencion habitual: 0/1 = normal, otro valor = alerta. Devuelve
  /// las etiquetas legibles de las ruedas afectadas (vacio = todo normal).
  List<String> get tirePressureAlerts {
    final map = {
      'leftFrontTirePressureState': 'Del. izq.',
      'rightFrontTirePressureState': 'Del. der.',
      'leftRearTirePressureState': 'Tras. izq.',
      'rightRearTirePressureState': 'Tras. der.',
    };
    final out = <String>[];
    map.forEach((key, label) {
      final v = raw[key];
      final n = v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
      if (n != null && n > 1) out.add(label);
    });
    return out;
  }

  /// Potencia instantanea de la bateria en kW (corriente x voltaje / 1000).
  /// Positivo = saliendo (consumo/carga), negativo = entrando por regeneracion.
  /// Unidades del coche confirmadas en A y V (p. ej. 19,8 A x 422,1 V = 8,4 kW).
  double? get batteryPowerKw {
    final c = raw['batteryCurrent'];
    final v = raw['batteryVoltage'];
    final cn = c is num ? c.toDouble() : (c is String ? double.tryParse(c) : null);
    final vn = v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    if (cn == null || vn == null) return null;
    return cn * vn / 1000.0;
  }

  bool get isPluggedIn => (acInputSlowCharge ?? false) || (dcInputFastCharge ?? false);

  factory VehicleStatus.fromRaw(Map<String, dynamic> statusData) {
    final m = mergeSignalToNamed(statusData);
    return VehicleStatus(
      soc: _asInt(m['soc']), preciseSoc: _asDouble(m['preciseSoc']), chargeState: _asInt(m['chargeState']),
      acInputSlowCharge: _asBool(m['acInputSlowCharge']), dcInputFastCharge: _asBool(m['dcInputFastCharge']),
      batteryThermalRequest: _asInt(m['batteryThermalRequest']), liveRemainingRange: _asInt(m['liveRemainingRange']),
      latitude: _asDouble(m['latitude']), longitude: _asDouble(m['longitude']), acSwitch: _asBool(m['acSwitch']),
      driverDoorLockStatus: _asBool(m['driverDoorLockStatus']), bbcmBackDoorStatus: _asBool(m['bbcmBackDoorStatus']),
      sentryMode: _asInt(m['sentryMode']), totalMileage: _asInt(m['totalMileage']),
      speed: _asDouble(m['speed']), chargeCompleted: _asBool(m['chargeCompleted']),
      leftFrontTireKpa: _asInt(m['leftFrontTirePressure']), rightFrontTireKpa: _asInt(m['rightFrontTirePressure']),
      leftRearTireKpa: _asInt(m['leftRearTirePressure']), rightRearTireKpa: _asInt(m['rightRearTirePressure']),
      raw: m,
    );
  }
}

class Vehicle {
  final String vin;
  final String carType;
  final String? nickName;
  final String? carId;

  Vehicle({required this.vin, required this.carType, this.nickName, this.carId});

  String get statusPath =>
      (carType.toLowerCase() == 'b10' || carType.toLowerCase() == 'b11') ? 'c10' : carType.toLowerCase();

  factory Vehicle.fromDict(Map<String, dynamic> d) => Vehicle(
        vin: d['vin']?.toString() ?? '',
        carType: d['carType']?.toString() ?? '',
        nickName: d['nickName']?.toString(),
        carId: d['carId']?.toString(),
      );
}

class LeapmotorApiException implements Exception {
  final int statusCode;
  final String message;
  LeapmotorApiException(this.statusCode, this.message);
  @override
  String toString() => 'API Error $statusCode: $message';
}

const String kCmdLock = '110';
const String kCmdTrunk = '130';
const String kCmdFindCar = '120';
const String kCmdBatteryPreheat = '160';
const String kCmdSentryMode = '220';
const String kCmdSteeringWheelHeat = '320';
const String kCmdSeatHeat = '301';
const String kCmdSeatVentilation = '370';
const String kCmdClimate = '170';
const String kCmdChargePlan = '190';
const String kCmdUnlockCharger = '192';
const String kCmdSunshade = '240';
const String kCmdWindows = '230';

/// Datos de sesión exportables para persistir el login (evita re-login completo).
class SessionData {
  final String userId, token, refreshToken, deviceId;
  final String signIkm, signSalt, signInfo;
  final String accountId, uid, base64Cert;

  SessionData({
    required this.userId, required this.token, required this.refreshToken, required this.deviceId,
    required this.signIkm, required this.signSalt, required this.signInfo,
    required this.accountId, required this.uid, required this.base64Cert,
  });

  Map<String, String> toMap() => {
        'userId': userId, 'token': token, 'refreshToken': refreshToken, 'deviceId': deviceId,
        'signIkm': signIkm, 'signSalt': signSalt, 'signInfo': signInfo,
        'accountId': accountId, 'uid': uid, 'base64Cert': base64Cert,
      };

  factory SessionData.fromMap(Map<String, String> m) => SessionData(
        userId: m['userId']!, token: m['token']!, refreshToken: m['refreshToken']!, deviceId: m['deviceId']!,
        signIkm: m['signIkm']!, signSalt: m['signSalt']!, signInfo: m['signInfo']!,
        accountId: m['accountId']!, uid: m['uid']!, base64Cert: m['base64Cert']!,
      );
}

class LeapmotorApiClient {
  final IOClient staticClient;
  IOClient? _accountClient;

  String? userId;
  String? token;
  String? refreshToken;
  String deviceId = _generateDeviceId();
  Uint8List? _signKey;
  bool _remoteCertSynced = false;
  List<Vehicle> _vehicles = [];

  // Guardados tras login/restore para poder exportar la sesión
  String? _signIkmStr, _signSaltStr, _signInfoStr, _accountId, _uid, _base64Cert;

  LeapmotorApiClient(this.staticClient);

  Map<String, String> _baseHeaders(String nonce, String timestamp, String sign) => {
        'acceptLanguage': kLanguage, 'channel': kChannel, 'deviceType': kDeviceType, 'source': kSource,
        'version': kAppVersion, 'nonce': nonce, 'deviceId': deviceId, 'timestamp': timestamp, 'sign': sign,
        'X-P12_ENC_ALG': kP12EncAlg, 'Content-Type': 'application/x-www-form-urlencoded',
      };

  String _nonce() => (Random().nextInt(9900000) + 100000).toString();
  String _ts() => DateTime.now().millisecondsSinceEpoch.toString();
  Map<String, String> _authHeaders() => {'userId': userId!, 'token': token!};

  Future<void> login(String email, String password) async {
    final nonce = _nonce();
    final timestamp = _ts();
    final signInput = [
      kLanguage, kDeviceType, deviceId, '1', email, '0', '1', nonce, password, kPolicyId, kSource, timestamp, kAppVersion,
    ].join('');
    final sign = crypto.sha256.convert(utf8.encode(signInput)).toString();
    final headers = _baseHeaders(nonce, timestamp, sign);
    final body = 'isRecoverAcct=0&password=${Uri.encodeComponent(password)}&policyId=$kPolicyId'
        '&loginMethod=1&email=${Uri.encodeComponent(email)}';

    final response =
        await staticClient.post(Uri.parse('$kBaseUrl/carownerservice/oversea/acct/v1/login'), headers: headers, body: body);
    final data = _parseBody(response.statusCode, response.body, 'login');
    final loginData = data['data'] as Map<String, dynamic>?;
    if (loginData == null) throw LeapmotorApiException(0, 'Missing login data');

    userId = loginData['id']?.toString();
    token = loginData['token']?.toString();
    refreshToken = loginData['refreshToken']?.toString() ?? '';
    _signIkmStr = loginData['signIkm']?.toString() ?? '';
    _signSaltStr = loginData['signSalt']?.toString() ?? '';
    _signInfoStr = loginData['signInfo']?.toString() ?? '';
    _accountId = loginData['id']?.toString() ?? '';
    _uid = loginData['uid']?.toString() ?? '';
    _base64Cert = loginData['base64Cert']?.toString() ?? '';

    _signKey = hkdfSha256(
      Uint8List.fromList(utf8.encode(_signIkmStr!)),
      Uint8List.fromList(utf8.encode(_signSaltStr!)),
      Uint8List.fromList(utf8.encode(_signInfoStr!)),
      32,
    );
    deviceId = deriveSessionDeviceId(token, deviceId);
    _remoteCertSynced = false;
    await _loadAccountCertFromBase64(_base64Cert!, _accountId!, _uid!);
  }

  /// Restaura una sesión guardada sin volver a hacer login completo.
  Future<void> restoreSession(SessionData session) async {
    userId = session.userId;
    token = session.token;
    refreshToken = session.refreshToken;
    deviceId = session.deviceId;
    _signIkmStr = session.signIkm;
    _signSaltStr = session.signSalt;
    _signInfoStr = session.signInfo;
    _accountId = session.accountId;
    _uid = session.uid;
    _base64Cert = session.base64Cert;
    _signKey = hkdfSha256(
      Uint8List.fromList(utf8.encode(session.signIkm)),
      Uint8List.fromList(utf8.encode(session.signSalt)),
      Uint8List.fromList(utf8.encode(session.signInfo)),
      32,
    );
    _remoteCertSynced = false;
    await _loadAccountCertFromBase64(session.base64Cert, session.accountId, session.uid);
  }

  SessionData exportSession() {
    if (userId == null || token == null || _signIkmStr == null || _base64Cert == null) {
      throw StateError('No hay sesión activa para exportar.');
    }
    return SessionData(
      userId: userId!, token: token!, refreshToken: refreshToken ?? '', deviceId: deviceId,
      signIkm: _signIkmStr!, signSalt: _signSaltStr!, signInfo: _signInfoStr!,
      accountId: _accountId!, uid: _uid!, base64Cert: _base64Cert!,
    );
  }

  /// Refresca el token de acceso usando el refreshToken (evita pedir usuario/contraseña de nuevo).
  Future<void> tokenRefresh() async {
    if (refreshToken == null || refreshToken!.isEmpty) {
      throw LeapmotorApiException(0, 'No hay refreshToken disponible.');
    }
    final headers = _signedHeaders(bodyParams: {'refreshToken': refreshToken!})..addAll(_authHeaders());
    final data = 'refreshToken=${Uri.encodeComponent(refreshToken!)}';
    final response = await _accountClient!.post(
      Uri.parse('$kBaseUrl/carownerservice/oversea/acct/v1/token/refresh'),
      headers: headers,
      body: data,
    );
    final result = _parseBody(response.statusCode, response.body, 'token refresh');
    final refreshData = result['data'] as Map<String, dynamic>? ?? {};
    token = refreshData['token']?.toString();
    refreshToken = refreshData['refreshToken']?.toString() ?? '';
  }

  /// Intenta usar la sesión tal cual; si el token ha expirado, refresca y reintenta una vez.
  Future<T> withTokenRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on LeapmotorApiException catch (e) {
      if (!e.message.toLowerCase().contains('token')) rethrow;
      await tokenRefresh();
      return await action();
    }
  }

  Future<void> _loadAccountCertFromBase64(String base64Cert, String accountId, String uid) async {
    if (base64Cert.isEmpty) throw LeapmotorApiException(0, 'No base64Cert available');
    final p12Bytes = base64.decode(base64Cert);
    final password = deriveAccountP12Password(accountId, uid);
    final securityContext = SecurityContext(withTrustedRoots: true);
    securityContext.useCertificateChainBytes(p12Bytes, password: password);
    securityContext.usePrivateKeyBytes(p12Bytes, password: password);
    final httpClient = HttpClient(context: securityContext);
    httpClient.badCertificateCallback = (_, __, ___) => true;
    _accountClient = IOClient(httpClient);
  }

  Map<String, dynamic> _parseBody(int statusCode, String body, String label) {
    late Map<String, dynamic> data;
    try {
      data = json.decode(body) as Map<String, dynamic>;
    } catch (_) {
      throw LeapmotorApiException(statusCode, '$label returned non-JSON: ${body.substring(0, body.length < 200 ? body.length : 200)}');
    }
    if (statusCode != 200 || data['code'] != 0) {
      throw LeapmotorApiException((data['code'] as int?) ?? -1, data['message']?.toString() ?? '$label failed');
    }
    return data;
  }

  Map<String, String> _signedHeaders({String? vin, Map<String, String>? bodyParams}) {
    final nonce = _nonce();
    final timestamp = _ts();
    final signFields = <String, String>{
      'acceptLanguage': kLanguage, 'channel': kChannel, 'deviceId': deviceId, 'deviceType': kDeviceType,
      'nonce': nonce, 'source': kSource, 'timestamp': timestamp, 'version': kAppVersion,
      if (vin != null) 'vin': vin,
      ...?bodyParams,
    };
    final sortedKeys = signFields.keys.toList()..sort();
    final signInput = sortedKeys.map((k) => signFields[k]!).join('');
    final sign = crypto.Hmac(crypto.sha256, _signKey!).convert(utf8.encode(signInput)).toString();
    return _baseHeaders(nonce, timestamp, sign);
  }

  Future<List<Vehicle>> getVehicleList() => withTokenRetry(() async {
        if (_accountClient == null) throw Exception('Not logged in');
        final headers = _signedHeaders()..addAll(_authHeaders());
        final response = await _accountClient!.post(
          Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/list'),
          headers: headers,
          body: '',
        );
        final data = _parseBody(response.statusCode, response.body, 'vehicle list');
        final listData = data['data'] as Map<String, dynamic>? ?? {};
        final vehicles = <Vehicle>[];
        for (final bucket in ['bindcars', 'sharedcars']) {
          for (final item in (listData[bucket] as List<dynamic>? ?? [])) {
            vehicles.add(Vehicle.fromDict(item as Map<String, dynamic>));
          }
        }
        _vehicles = vehicles;
        return vehicles;
      });

  Vehicle _findVehicle(String vin) =>
      _vehicles.firstWhere((v) => v.vin == vin, orElse: () => throw LeapmotorApiException(0, 'Vehicle not found for VIN $vin'));

  Future<VehicleStatus> getVehicleStatus(String vin) => withTokenRetry(() async {
        final vehicle = _findVehicle(vin);
        final headers = _signedHeaders(vin: vin)..addAll(_authHeaders());
        final response = await _accountClient!.post(
          Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/status/get/${vehicle.statusPath}'),
          headers: headers,
          body: 'vin=${Uri.encodeComponent(vin)}',
        );
        final data = _parseBody(response.statusCode, response.body, 'vehicle status');
        return VehicleStatus.fromRaw((data['data'] as Map<String, dynamic>?) ?? {});
      });

  /// Consulta el horario/limite de carga actual (cmd_id=190) sin ejecutar ningun comando.
  Future<Map<String, dynamic>> getChargeSchedule(String vin) => withTokenRetry(() async {
    final headers = _signedHeaders(vin: vin, bodyParams: {'cmdId': '190'})..addAll(_authHeaders());
    final response = await _accountClient!.post(
      Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/app/remote/ctl/getAppointment'),
      headers: headers,
      body: 'vin=${Uri.encodeComponent(vin)}&cmdId=190',
    );
    Map<String, dynamic> body;
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
    final resultCode = body['result'] ?? body['code'];
    if (response.statusCode != 200 || (resultCode != 0 && resultCode != null)) return {};
    final rawData = body['data'];
    if (rawData == null) return {};
    if (rawData is String) {
      try {
        return Map<String, dynamic>.from(json.decode(rawData) as Map);
      } catch (_) {
        return {};
      }
    }
    if (rawData is Map) return Map<String, dynamic>.from(rawData);
    return {};
  });

  Future<void> _ensureRemoteCertSync() async {
    if (_remoteCertSynced) return;
    final headers = _signedHeaders()..addAll(_authHeaders());
    final response = await staticClient.post(
      Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/cert/sync'),
      headers: headers,
      body: '',
    );
    _parseBody(response.statusCode, response.body, 'cert sync');
    _remoteCertSynced = true;
  }

  Future<Map<String, dynamic>> _remoteControlWithPin({
    required String vin, required String cmdId, required String cmdContent, required String pin, required String actionLabel,
  }) =>
      withTokenRetry(() async {
        if (token == null) throw LeapmotorApiException(0, 'Not logged in');
        final operatePassword = encryptOperatePassword(pin, token);
        await _ensureRemoteCertSync();

        final verifyHeaders =
            _signedHeaders(vin: vin, bodyParams: {'operatePassword': operatePassword})..addAll(_authHeaders());
        final verifyBody = 'operatePassword=${Uri.encodeComponent(operatePassword)}&vin=${Uri.encodeComponent(vin)}';
        final verifyResponse = await _accountClient!.post(
          Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/operPwd/verify'),
          headers: verifyHeaders,
          body: verifyBody,
        );
        _parseBody(verifyResponse.statusCode, verifyResponse.body, 'remote verify');

        final ctlHeaders = _signedHeaders(
          vin: vin,
          bodyParams: {'cmdContent': cmdContent, 'cmdId': cmdId, 'operatePassword': operatePassword},
        )..addAll(_authHeaders());
        final ctlBody = 'cmdContent=${Uri.encodeComponent(cmdContent)}&vin=${Uri.encodeComponent(vin)}'
            '&cmdId=${Uri.encodeComponent(cmdId)}&operatePassword=${Uri.encodeComponent(operatePassword)}';
        final response = await _accountClient!.post(
          Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/app/remote/ctl'),
          headers: ctlHeaders,
          body: ctlBody,
        );
        final result = _parseBody(response.statusCode, response.body, 'remote $actionLabel');

        final remoteData = result['data'] as Map<String, dynamic>? ?? {};
        final remoteCtlId = remoteData['remoteCtlId']?.toString();
        if (remoteCtlId != null) {
          await _pollRemoteControlResult(
            remoteCtlId: remoteCtlId,
            timeoutMs: _asInt(remoteData['queryRemoteCtlResultTimeout']) ?? 30000,
            intervalMs: _asInt(remoteData['queryInterval']) ?? 2000,
          );
        }
        return result;
      });

  Future<void> _pollRemoteControlResult({required String remoteCtlId, required int timeoutMs, required int intervalMs}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs < 1000 ? 1000 : timeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      final headers = _signedHeaders(bodyParams: {'remoteCtlId': remoteCtlId})..addAll(_authHeaders());
      final response = await _accountClient!.post(
        Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/app/remote/ctl/result/query'),
        headers: headers,
        body: 'remoteCtlId=${Uri.encodeComponent(remoteCtlId)}',
      );
      final result = _parseBody(response.statusCode, response.body, 'remote control result');
      if (result['data'] == 1) return;
      final sleepMs = intervalMs < 250 ? 250 : intervalMs;
      await Future.delayed(Duration(milliseconds: sleepMs));
    }
    throw LeapmotorApiException(0, 'Timed out waiting for remote control result');
  }

  Future<void> lockVehicle(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdLock, cmdContent: '{"value":"lock"}', pin: pin, actionLabel: 'lock');
  Future<void> unlockVehicle(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdLock, cmdContent: '{"value":"unlock"}', pin: pin, actionLabel: 'unlock');
  Future<void> findVehicle(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdFindCar, cmdContent: '{"value":"true"}', pin: pin, actionLabel: 'find_car');
  Future<void> openTrunk(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdTrunk, cmdContent: '{"value":"true"}', pin: pin, actionLabel: 'trunk_open');
  Future<void> closeTrunk(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdTrunk, cmdContent: '{"value":"false"}', pin: pin, actionLabel: 'trunk_close');
  Future<void> batteryPreheatOn(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdBatteryPreheat, cmdContent: '{"value":"ptcon"}', pin: pin, actionLabel: 'battery_preheat_on');
  Future<void> batteryPreheatOff(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdBatteryPreheat, cmdContent: '{"value":"ptcoff"}', pin: pin, actionLabel: 'battery_preheat_off');
  Future<void> sentryModeOn(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdSentryMode, cmdContent: '{"value":"1"}', pin: pin, actionLabel: 'sentry_mode_on');
  Future<void> sentryModeOff(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdSentryMode, cmdContent: '{"value":"0"}', pin: pin, actionLabel: 'sentry_mode_off');
  Future<void> unlockCharger(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdUnlockCharger, cmdContent: '{"operation":"unlock"}', pin: pin, actionLabel: 'unlock_charger');
  Future<void> steeringWheelHeatOn(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdSteeringWheelHeat, cmdContent: '{"value":"on"}', pin: pin, actionLabel: 'steering_wheel_heat_on');
  Future<void> steeringWheelHeatOff(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdSteeringWheelHeat, cmdContent: '{"value":"off"}', pin: pin, actionLabel: 'steering_wheel_heat_off');

  Future<void> seatHeat(String vin, String pin, {required int position, required int level}) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdSeatHeat, cmdContent: '{"value":"$position,$level"}', pin: pin, actionLabel: 'seat_heat');
  Future<void> seatVentilation(String vin, String pin, {required int position, required int level}) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdSeatVentilation, cmdContent: '{"value":"$position,$level"}', pin: pin, actionLabel: 'seat_ventilation');

  Future<void> quickCool(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdClimate,
      cmdContent: json.encode({'circle': 'in', 'mode': 'cold', 'operate': 'manual', 'position': 'all', 'temperature': '18', 'windlevel': '7', 'wshld': '0'}),
      pin: pin, actionLabel: 'quick_cool');
  Future<void> quickHeat(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdClimate,
      cmdContent: json.encode({'circle': 'in', 'mode': 'hot', 'operate': 'manual', 'position': 'all', 'temperature': '32', 'windlevel': '7', 'wshld': '0'}),
      pin: pin, actionLabel: 'quick_heat');
  Future<void> windshieldDefrost(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdClimate,
      cmdContent: json.encode({'circle': 'in', 'mode': 'hot', 'operate': 'manual', 'position': 'all', 'temperature': '32', 'windlevel': '7', 'wshld': '1'}),
      pin: pin, actionLabel: 'windshield_defrost');
  Future<void> acOff(String vin, String pin) => _remoteControlWithPin(
      vin: vin, cmdId: kCmdClimate,
      cmdContent: json.encode({'circle': 'out', 'mode': 'wind', 'operate': 'close', 'position': 'all', 'temperature': '26', 'windlevel': '3', 'wshld': '0'}),
      pin: pin, actionLabel: 'ac_off');
  /// Clima normal PERMANENTE (cmd 170): sigue encendido hasta apagarlo con
  /// acOff. A diferencia de prepareCarNow (360), que se auto-apaga ~20 min.
  /// Mismo formato de payload que quickCool/quickHeat, con temperatura libre.
  Future<void> climateManual(String vin, String pin,
          {required bool heat, required String temperature}) =>
      _remoteControlWithPin(
          vin: vin,
          cmdId: kCmdClimate,
          cmdContent: json.encode({
            'circle': heat ? 'out' : 'in',
            'mode': heat ? 'hot' : 'cold',
            'operate': 'manual',
            'position': 'all',
            'temperature': temperature,
            'windlevel': '5',
            'wshld': '0'
          }),
          pin: pin,
          actionLabel: 'climate_manual');







  /// Establece el limite de carga. IMPORTANTE (experimental): se fuerza
  /// chargeEnable=1 con ventana 00:00-23:59 todos los dias, porque se observo
  /// que con chargeEnable=0 (valor por defecto anterior) el servidor acepta
  /// el comando pero el coche no aplica realmente el limite (el propio estado
  /// del vehiculo mostraba "isEnable": 0 tras enviarlo). Verificar con la
  /// pantalla de debug (snapshot/diff en 'config') tras usarlo.
  Future<void> setChargeLimit(String vin, String pin, int percent) async {
    Map<String, dynamic> schedule = {};
    try {
      schedule = await getChargeSchedule(vin);
    } catch (_) {}

    final cmdContent = json.encode({
      'chargeEnable': 1,
      'chargesoc': percent,
      'circulation': schedule['circulation'] ?? 0,
      'cycles': schedule['cycles'] ?? '1,2,3,4,5,6,7',
      'endtime': '23:59',
      'recharge': schedule['recharge'] ?? 0,
      'starttime': '00:00',
    });
    await _remoteControlWithPin(vin: vin, cmdId: kCmdChargePlan, cmdContent: cmdContent, pin: pin, actionLabel: 'set_charge_limit');
  }

  // -- Novedades v3.7.0: persiana, ventanillas, techo solar --
  // Nota: el B10 solo actúa realmente sobre 0/2/5/10 en la escala 0-10
  // (la nube acepta otros valores con code=0 pero el coche los ignora).
  Future<void> sunshadeOpen(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdSunshade, cmdContent: '{"value":"10"}', pin: pin, actionLabel: 'sunshade_open');
  Future<void> sunshadeClose(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdSunshade, cmdContent: '{"value":"0"}', pin: pin, actionLabel: 'sunshade_close');
  Future<void> windowsOpen(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdWindows, cmdContent: '{"value":"10"}', pin: pin, actionLabel: 'windows_open');
  Future<void> windowsClose(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: kCmdWindows, cmdContent: '{"value":"0"}', pin: pin, actionLabel: 'windows_close');


  // -- Experimental: comando de "video" (cmd_id=290). Se sospecha que puede
  // controlar el interruptor de la grabadora de conducción en bucle (dashcam
  // nativa del B10), visto en el menu Ajustes de la propia pantalla del coche.
  // No confirmado; probar distintos valores de 'operation' con el snapshot/diff
  // de la pantalla de debug.
  Future<void> videoCommand(String vin, String pin, String operation) => _remoteControlWithPin(
      vin: vin, cmdId: '290', cmdContent: json.encode({'operation': operation}), pin: pin, actionLabel: 'video_$operation');


  // -- Experimental: ON3 / "modo acampada" (cmd_id=410).
  // No confirmado que sea realmente este modo, ni el valor exacto que espera
  // el servidor. Probar con el snapshot/diff de la pantalla de debug.
  Future<void> on3On(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: '410', cmdContent: '{"value":"1"}', pin: pin, actionLabel: 'on3_on');
  Future<void> on3Off(String vin, String pin) =>
      _remoteControlWithPin(vin: vin, cmdId: '410', cmdContent: '{"value":"0"}', pin: pin, actionLabel: 'on3_off');


  // ============================================================
  // Precondicionado (cmd_id=360 inmediato, cmd_id=361 programado).
  // El formato exacto de "datacontent" se infiere por simetria con la
  // lectura del horario (get_prepare_car_schedule), no esta 100% confirmado
  // desde el codigo fuente. Verificar sintiendo si el coche realmente
  // climatiza a la hora programada.
  // ============================================================

  Map<String, dynamic> _buildAirConditionBundle({
    required bool enable,
    required String mode, // 'hot', 'cold', 'nohotcold'
    required String temperature,
    int windlevel = 5,
  }) {
    return {
      'enable': enable,
      'mode': mode,
      'circle': mode == 'cold' ? 'in' : 'out',
      'windlevel': windlevel,
      'wshld': '0',
      'operate': enable ? 'manual' : 'close',
      'temperature': temperature,
      'position': 'all',
    };
  }

  /// Activa el precondicionado ahora mismo (climatizacion). El gateway lo
  /// detiene automaticamente pasados ~20 minutos, segun la documentacion
  /// de la version programada.
  Future<void> prepareCarNow(String vin, String pin, {
    required bool heat,
    required String temperature,
    bool steeringWheelHeat = false,
  }) async {
    final datacontent = <String, dynamic>{
      'air_condition': _buildAirConditionBundle(enable: true, mode: heat ? 'hot' : 'cold', temperature: temperature),
      if (steeringWheelHeat) 'steeringWheelHeatCtrl': {'enable': true, 'level': 2},
    };
    await _remoteControlWithPin(
      vin: vin, cmdId: '360', cmdContent: json.encode(datacontent), pin: pin, actionLabel: 'prepare_car_now',
    );
  }

  /// Consulta las entradas programadas de precondicionado (cmd_id=361).
  Future<List<Map<String, dynamic>>> getPrepareCarSchedule(String vin) => withTokenRetry(() async {
    final headers = _signedHeaders(vin: vin, bodyParams: {'cmdId': '361'})..addAll(_authHeaders());
    final response = await _accountClient!.post(
      Uri.parse('$kBaseUrl/carownerservice/oversea/vehicle/v1/app/remote/ctl/getAppointment'),
      headers: headers,
      body: 'vin=${Uri.encodeComponent(vin)}&cmdId=361',
    );
    Map<String, dynamic> body;
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return [];
    }
    final resultCode = body['result'] ?? body['code'];
    if (response.statusCode != 200 || (resultCode != 0 && resultCode != null)) return [];
    final rawData = body['data'];
    if (rawData == null) return [];
    dynamic parsed = rawData;
    if (rawData is String) {
      try {
        parsed = json.decode(rawData);
      } catch (_) {
        return [];
      }
    }
    if (parsed is Map && parsed['controls'] is List) {
      return List<Map<String, dynamic>>.from((parsed['controls'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return [];
  });

  /// Sustituye TODAS las entradas programadas de precondicionado por la
  /// lista dada (reemplazo completo, no incremental). Pasa una lista vacia
  /// para cancelar todas.
  Future<void> setPrepareCarSchedule(String vin, String pin, List<Map<String, dynamic>> controls) async {
    final cmdContent = json.encode({'controls': controls});
    await _remoteControlWithPin(
      vin: vin, cmdId: '361', cmdContent: cmdContent, pin: pin, actionLabel: 'set_prepare_car_schedule',
    );
  }

  Future<void> cancelPrepareCarSchedule(String vin, String pin) => setPrepareCarSchedule(vin, pin, []);

  /// Construye una entrada de horario de precondicionado.
  Map<String, dynamic> buildPrepareCarEntry({
    required DateTime startTime,
    required List<int> days, // 0=domingo .. 6=sabado; vacio = una sola vez
    required bool heat,
    required String temperature,
    bool steeringWheelHeat = false,
    String? setId,
  }) {
    final dt = '${startTime.year.toString().padLeft(4, '0')}-'
        '${startTime.month.toString().padLeft(2, '0')}-'
        '${startTime.day.toString().padLeft(2, '0')} '
        '${startTime.hour.toString().padLeft(2, '0')}:'
        '${startTime.minute.toString().padLeft(2, '0')}:00';
    return {
      'datacontent': {
        'air_condition': _buildAirConditionBundle(enable: true, mode: heat ? 'hot' : 'cold', temperature: temperature),
        if (steeringWheelHeat) 'steeringWheelHeatCtrl': {'enable': true, 'level': 2},
      },
      'days': days,
      'enable': true,
      'set_id': setId ?? 'prepare_${DateTime.now().millisecondsSinceEpoch}',
      'start_time': dt,
    };
  }


  // ============================================================
  // Limite de velocidad (cmd_id=510, confirmado en models.py:
  // RemoteActionCtlSpeedLimit). Valor: velocidad en km/h como string.
  // ============================================================
  Future<void> setSpeedLimit(String vin, String pin, int kmh) => _remoteControlWithPin(
      vin: vin, cmdId: '510', cmdContent: json.encode({'value': kmh.toString()}), pin: pin, actionLabel: 'set_speed_limit');

  // ============================================================
  // Historial de mensajes de la app oficial (confirmado en client.py:
  // /carownerservice/oversea/message/v1/list y /message/v1/unread/count)
  // ============================================================
  Future<Map<String, dynamic>> getMessages(int pageNo, int pageSize) => withTokenRetry(() async {
    final bodyParams = {'pageNo': pageNo.toString(), 'pageSize': pageSize.toString()};
    final headers = _signedHeaders(bodyParams: bodyParams)..addAll(_authHeaders());
    final response = await _accountClient!.post(
      Uri.parse('$kBaseUrl/carownerservice/oversea/message/v1/list'),
      headers: headers,
      body: 'pageNo=$pageNo&pageSize=$pageSize',
    );
    final data = _parseBody(response.statusCode, response.body, 'message list');
    final list = data['data'] as Map<String, dynamic>? ?? {};
    return {
      'count': list['count'] ?? 0,
      'messages': List<Map<String, dynamic>>.from((list['list'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))),
    };
  });

  Future<int> getUnreadMessageCount() => withTokenRetry(() async {
    final headers = _signedHeaders()..addAll(_authHeaders());
    final response = await _accountClient!.post(
      Uri.parse('$kBaseUrl/carownerservice/oversea/message/v1/unread/count'),
      headers: headers,
      body: '',
    );
    final data = _parseBody(response.statusCode, response.body, 'unread message count');
    return _asInt((data['data'] as Map<String, dynamic>?)?['unread']) ?? 0;
  });


  /// Establece el horario completo de carga (cmd_id=190): habilitado, limite
  /// de SOC, franja horaria y dias de la semana. A diferencia de setChargeLimit
  /// (que fuerza una ventana 24h para que el limite siempre se aplique), este
  /// metodo permite una ventana horaria real (ej. cargar solo de 00:00 a 07:00).
  ///
  /// NOTA (experimental): el formato de "cycles" (dias de la semana) se
  /// construye como lista de numeros 1-7 (1=lunes) separados por coma, igual
  /// que el valor por defecto que ya usa setChargeLimit. No esta 100%
  /// verificado contra el formato interno real; comprobar con la pantalla de
  /// debug (snapshot/diff sobre 'config') tras guardar.
  Future<void> setChargeSchedule(String vin, String pin, {
    required bool enabled,
    required int socLimit,
    required String startTime,
    required String endTime,
    required List<int> weekdays, // 1=lunes .. 7=domingo
    int circulation = 0,
    int recharge = 0,
  }) async {
    final cmdContent = json.encode({
      'chargeEnable': enabled ? 1 : 0,
      'chargesoc': socLimit,
      'circulation': circulation,
      'cycles': weekdays.join(','),
      'endtime': endTime,
      'recharge': recharge,
      'starttime': startTime,
    });
    await _remoteControlWithPin(vin: vin, cmdId: kCmdChargePlan, cmdContent: cmdContent, pin: pin, actionLabel: 'set_charge_schedule');
  }


  // -- Experimental: comando de "hotspot" (cmd_id=140). En el cliente Python
  // de referencia se envia SIN parametros (probablemente un disparador, no un
  // toggle con valor). No confirmado si controla el hotspot WiFi de pasajeros
  // o algo relacionado con mantener el TCU conectado a una red domestica -
  // podrian ser cosas totalmente distintas. Probar variantes con debug.
  Future<void> hotspotCommand(String vin, String pin, String cmdContent) => _remoteControlWithPin(
      vin: vin, cmdId: '140', cmdContent: cmdContent, pin: pin, actionLabel: 'hotspot');

  static String _generateDeviceId() {
    final rnd = Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

Future<IOClient> createStaticClient() async {
  final pair = await loadClientCert();
  final securityContext = SecurityContext(withTrustedRoots: true);
  securityContext.useCertificateChainBytes(pair.cert);
  securityContext.usePrivateKeyBytes(pair.key);
  final httpClient = HttpClient(context: securityContext);
  httpClient.badCertificateCallback = (_, __, ___) => true;
  return IOClient(httpClient);
}
