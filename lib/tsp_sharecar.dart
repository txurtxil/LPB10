import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'cert_store.dart';

/// Cliente del canal TSP (socket TLS + protocolo binario enmarcado) usado por
/// el API owner-side de Leapmotor (sharecar, etc.).
///
/// Framing capturado del trafico real (2026-10-20):
///   [00 00] [2B len big-endian] [1B cmd] [4B seq little-endian] [payload]
///   cmd 01 = payload en claro (url-encoded: a=b&c=d)
///   Respuesta = mismo framing; el payload JSON llega en claro (cmd 01) tras
///   el handshake (cmd 05/04 = negociacion de sesion, la omitimos replicando
///   solo el cmd 01 que el servidor acepta tras el TLS).
class TspClient {
  static const String _host = 'appgateway.leapmotor-international.de';
  static const int _port = 443;

  Socket? _socket;
  final _seq = 0;
  int _nextSeq = 0;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  StreamSubscription<Uint8List>? _sub;
  final List<int> _buf = [];

  Future<void> connect() async {
    if (_socket != null) return;
    final pair = await loadClientCert();
    final ctx = SecurityContext(withTrustedRoots: true);
    ctx.useCertificateChainBytes(pair.cert);
    ctx.usePrivateKeyBytes(pair.key);
    final s = await SecureSocket.connect(_host, _port, context: ctx,
        onBadCertificate: (_) => false);
    _socket = s;
    _sub = s.listen(_onData, onError: (e) {
      for (final c in _pending.values) {
        c.completeError('TSP socket error: $e');
      }
      _pending.clear();
    }, onDone: () {
      for (final c in _pending.values) {
        c.completeError('TSP socket closed');
      }
      _pending.clear();
      _socket = null;
    });
  }

  void _onData(Uint8List data) {
    _buf.addAll(data);
    // Parsear frames: [00 00][len hi][len lo][cmd][seq*4][payload len-5]
    while (_buf.length >= 7) {
      if (_buf[0] != 0 || _buf[1] != 0) { _buf.removeAt(0); continue; }
      final len = (_buf[2] << 8) | _buf[3];
      if (_buf.length < 2 + 2 + len) return; // incompleto, esperar mas
      final cmd = _buf[4];
      final seq = _buf[5] | (_buf[6] << 8) | (_buf[7] << 16) | (_buf[8] << 24);
      final payload = _buf.sublist(9, 2 + 2 + len);
      _buf.removeRange(0, 2 + 2 + len);
      if (cmd == 0x01) {
        // respuesta en claro: JSON
        try {
          final j = json.decode(utf8.decode(payload)) as Map<String, dynamic>;
          _pending.remove(seq)?.complete(j);
        } catch (_) {}
      }
      // cmd 04/05 = handshake/negociacion: ignorar (el servidor acepta cmd 01 tras TLS)
    }
  }

  /// Envia un comando y espera la respuesta JSON.
  Future<Map<String, dynamic>> command(String params) async {
    await connect();
    final seq = _nextSeq++;
    final payload = utf8.encode(params);
    final len = 1 + 4 + payload.length; // cmd + seq + payload
    final frame = Uint8List(4 + len);
    final b = ByteData.sublistView(frame);
    b.setUint16(2, len, Endian.big);
    b.setUint8(4, 0x01);
    b.setUint32(5, seq, Endian.little);
    frame.setRange(9, 9 + payload.length, payload);
    final c = Completer<Map<String, dynamic>>();
    _pending[seq] = c;
    _socket!.add(frame);
    await _socket!.flush();
    return c.future.timeout(const Duration(seconds: 20),
        onTimeout: () {
          _pending.remove(seq);
          throw TimeoutException('TSP command timeout', const Duration(seconds: 20));
        });
  }

  Future<void> close() async {
    await _sub?.cancel();
    _socket?.destroy();
    _socket = null;
    _pending.clear();
  }
}

/// API owner-side de compartir coche (usuarios con acceso) sobre el canal TSP.
class ShareCarApi {
  final TspClient _tsp = TspClient();

  /// Lista los usuarios con los que se ha compartido el coche.
  Future<List<SharedUser>> list(String vin, String ownerUserId) async {
    final r = await _tsp.command('carCode=$vin&userId=$ownerUserId');
    final list = (r['data']?['sharedcars'] as List?) ?? [];
    return list.map((e) => SharedUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Estado de un usuario compartido concreto.
  Future<Map<String, dynamic>> state(String vin, String ownerUserId, String shareUserId) async {
    return _tsp.command('state=yes&carCode=$vin&userId=$ownerUserId&shareUserId=$shareUserId');
  }

  /// Comparte el coche con un nuevo usuario (shareUserId = id del invitado).
  Future<Map<String, dynamic>> invite(String vin, String ownerUserId, String shareUserId) async {
    return _tsp.command('carCode=$vin&userId=$ownerUserId&shareUserId=$shareUserId');
  }

  /// Revoca el acceso de un usuario compartido.
  Future<Map<String, dynamic>> revoke(String vin, String ownerUserId, String shareUserId) async {
    return _tsp.command('carCode=$vin&userId=$ownerUserId&shareUserId=$shareUserId');
  }

  /// Cambia la duracion del prestamo.
  Future<Map<String, dynamic>> duration(String vin, int durationType) async {
    return _tsp.command('durationType=$durationType&carCode=$vin');
  }

  Future<void> close() => _tsp.close();
}

/// Modelo de un usuario compartido (capturado del JSON real).
class SharedUser {
  final int carId;
  final String userid;
  final String vin;
  final String shareType;
  final String moduleRights;
  final int? shareTime;
  final int durationType;
  final int? expireTime;
  final String carType;
  final String plateNumber;
  final String rightList;
  final List<String> abilities;
  final int? allocationCode;
  final String? nickName;
  final String? mobileNumber;

  SharedUser({
    required this.carId, required this.userid, required this.vin,
    required this.shareType, required this.moduleRights, this.shareTime,
    required this.durationType, this.expireTime, required this.carType,
    required this.plateNumber, required this.rightList, required this.abilities,
    this.allocationCode, this.nickName, this.mobileNumber,
  });

  factory SharedUser.fromJson(Map<String, dynamic> j) => SharedUser(
    carId: j['carId'] ?? 0,
    userid: (j['userid'] ?? '').toString(),
    vin: (j['vin'] ?? '').toString(),
    shareType: (j['shareType'] ?? '').toString(),
    moduleRights: (j['moduleRights'] ?? '').toString(),
    shareTime: j['shareTime'],
    durationType: j['durationType'] ?? 0,
    expireTime: j['expireTime'],
    carType: (j['carType'] ?? '').toString(),
    plateNumber: (j['plateNumber'] ?? '').toString(),
    rightList: (j['rightList'] ?? '').toString(),
    abilities: ((j['abilities'] as List?) ?? []).map((e) => e.toString()).toList(),
    allocationCode: j['allocationCode'],
    nickName: j['nickName'],
    mobileNumber: j['mobileNumber'],
  );
}
