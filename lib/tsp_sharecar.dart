import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http2/http2.dart';
import 'cert_store.dart';

/// Cliente del canal TSP de Leapmotor via HTTP/2 (el socket que la app
/// oficial usa para el API owner-side). TLS con mTLS (cert del usuario).
///
/// El "framing" que capturamos (cmd 01/04/05) era en realidad HTTP/2:
///   cmd 01 = DATA frame con el payload url-encoded (carCode=...&userId=...)
///   El :path HTTP/2 identifica el endpoint (getsharelist, addshare, etc).
///
/// IMPORTANTE: el path exacto aun no se ha capturado (las mutaciones de la
/// app oficial van cifradas). Este cliente asume REST-over-HTTP2 con los
/// paths candidatos del catalogo DEX; ajustar _path tras capturar el real.
class TspClient {
  static const String _host = 'appgateway.leapmotor-international.de';
  static const int _port = 443;

  ClientTransportConnection? _conn;

  Future<void> connect() async {
    if (_conn != null) return;
    final pair = await loadClientCert();
    final ctx = SecurityContext(withTrustedRoots: true);
    ctx.useCertificateChainBytes(pair.cert);
    ctx.usePrivateKeyBytes(pair.key);
    final socket = await SecureSocket.connect(_host, _port, context: ctx,
        onBadCertificate: (_) => true, supportedProtocols: ['h2']);
    _conn = ClientTransportConnection.viaSocket(socket);
  }

  /// Llama a un endpoint TSP. Devuelve el cuerpo de la respuesta (bytes).
  Future<Map<String, dynamic>> call(String method, String path,
      Map<String, String> params) async {
    await connect();
    final stream = _conn!.makeRequest([
      Header.ascii(':method', method),
      Header.ascii(':path', path),
      Header.ascii(':authority', _host),
      Header.ascii(':scheme', 'https'),
      Header.ascii('content-type', 'application/x-www-form-urlencoded'),
      Header.ascii('accept', 'application/json'),
    ]);
    final body = utf8.encode(params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&'));
    stream.sendData(body, endStream: true);

    final respHeaders = Completer<List<Header>>();
    final respBody = BytesBuilder();
    stream.incomingMessages.listen((msg) {
      if (msg is HeadersStreamMessage) {
        if (!respHeaders.isCompleted) respHeaders.complete(msg.headers);
      } else if (msg is DataStreamMessage) {
        respBody.add(msg.bytes);
      }
    }, onError: (e) {
      if (!respHeaders.isCompleted) respHeaders.completeError(e);
    }, onDone: () {
      if (!respHeaders.isCompleted) respHeaders.complete([]);
    });

    final headers = await respHeaders.future
        .timeout(const Duration(seconds: 20));
    final status = headers
        .where((h) => h.name == ':status')
        .map((h) => utf8.decode(h.value))
        .firstOrNull ?? '500';

    // Esperar el cuerpo completo
    await stream.incomingMessages.length
        .then((_) {})
        .catchError((_) {});
    final bodyStr = utf8.decode(respBody.toBytes(), allowMalformed: true);

    if (status != '200') {
      throw Exception('TSP HTTP2 $status: $bodyStr');
    }
    try {
      return json.decode(bodyStr) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': bodyStr};
    }
  }

  Future<void> close() async {
    await _conn?.finish();
    _conn = null;
  }
}

/// API owner-side de compartir coche sobre el canal TSP HTTP/2.
class ShareCarApi {
  final TspClient _tsp = TspClient();

  // Paths candidatos del catalogo DEX (ajustar tras capturar el real).
  static const _kListPaths = [
    '/carownerservice/oversea/sharecar/v1/getsharelist',
    '/carownerservice/oversea/sharecar/getsharelist',
  ];
  static const _kInvitePaths = [
    '/carownerservice/oversea/sharecar/v1/addshare',
    '/carownerservice/oversea/sharecar/addshare',
  ];
  static const _kRevokePaths = [
    '/carownerservice/oversea/sharecar/v1/deletesharecar',
    '/carownerservice/oversea/sharecar/deletesharecar',
  ];

  Future<List<SharedUser>> list(String vin, String ownerUserId) async {
    final r = await _tryPaths('POST', _kListPaths,
        {'carCode': vin, 'userId': ownerUserId});
    final list = (r['data']?['sharedcars'] as List?) ?? [];
    return list.map((e) => SharedUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> invite(String vin, String ownerUserId, String shareUserId) =>
      _tryPaths('POST', _kInvitePaths,
          {'carCode': vin, 'userId': ownerUserId, 'shareUserId': shareUserId});

  Future<Map<String, dynamic>> revoke(String vin, String ownerUserId, String shareUserId) =>
      _tryPaths('POST', _kRevokePaths,
          {'carCode': vin, 'userId': ownerUserId, 'shareUserId': shareUserId});

  Future<Map<String, dynamic>> _tryPaths(
      String method, List<String> paths, Map<String, String> params) async {
    Exception? last;
    for (final p in paths) {
      try {
        return await _tsp.call(method, p, params);
      } catch (e) {
        last = Exception('$p: $e');
      }
    }
    throw last ?? Exception('no paths');
  }

  Future<void> close() => _tsp.close();
}

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

extension on Stream<StreamMessage> {
  Future<int> get length async {
    var n = 0;
    await for (final _ in this) { n++; }
    return n;
  }
}
