// sentry_models.dart - Modelos del Modo Centinela (LMB10)

class SentrySnapshot {
  final bool? isLocked;
  final bool? anyDoorOpen;
  final bool? trunkOpen;
  final bool? anyWindowOpen;
  final bool? readyOn3; // READY / ON3 (senal 1258 en leapmotor-ha)
  final double? latitude;
  final double? longitude;
  final DateTime? collectTime; // frescura del dato TCU

  const SentrySnapshot({
    this.isLocked,
    this.anyDoorOpen,
    this.trunkOpen,
    this.anyWindowOpen,
    this.readyOn3,
    this.latitude,
    this.longitude,
    this.collectTime,
  });

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        'isLocked': isLocked,
        'anyDoorOpen': anyDoorOpen,
        'trunkOpen': trunkOpen,
        'anyWindowOpen': anyWindowOpen,
        'readyOn3': readyOn3,
        'latitude': latitude,
        'longitude': longitude,
        'collectTime': collectTime?.toIso8601String(),
      };

  factory SentrySnapshot.fromJson(Map<String, dynamic> j) => SentrySnapshot(
        isLocked: j['isLocked'] as bool?,
        anyDoorOpen: j['anyDoorOpen'] as bool?,
        trunkOpen: j['trunkOpen'] as bool?,
        anyWindowOpen: j['anyWindowOpen'] as bool?,
        readyOn3: j['readyOn3'] as bool?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        collectTime: j['collectTime'] == null
            ? null
            : DateTime.tryParse(j['collectTime'] as String),
      );
}

enum SentryEventType {
  armed,
  disarmed,
  nativeOn,
  nativeOff,
  nativeFailed,
  unlock,
  door,
  trunk,
  window,
  moved,
  wake,
  deterrent,
  offline,
  online,
  recOn,
  recOff,
  recFailed,
}

class SentryEvent {
  final SentryEventType type;
  final DateTime at;
  final String msg;
  final double? lat;
  final double? lon;
  final bool critical;

  SentryEvent(this.type, this.msg,
      {DateTime? at, this.lat, this.lon, this.critical = false})
      : at = at ?? DateTime.now();

  bool get hasLocation => lat != null && lon != null;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'at': at.toIso8601String(),
        'msg': msg,
        'lat': lat,
        'lon': lon,
        'critical': critical,
      };

  factory SentryEvent.fromJson(Map<String, dynamic> j) => SentryEvent(
        SentryEventType.values.byName(j['type'] as String),
        j['msg'] as String,
        at: DateTime.tryParse(j['at'] as String? ?? ''),
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        critical: j['critical'] as bool? ?? false,
      );
}

class SentryConfig {
  final int pollAwakeSec; // sondeo con pantalla abierta / coche despierto
  final int freshnessMin; // dato mas viejo que esto => TCU dormido
  final double moveMeters; // deriva GPS que cuenta como "movido"
  final bool useNative; // cmd 220 al armar
  final bool useDeterrent; // claxon+luces (cmd 120) ante manipulacion
  final bool reassertLock; // reenviar cierre (cmd 110) si desbloqueo
  final int deterrentCooldownMin;

  const SentryConfig({
    this.pollAwakeSec = 30,
    this.freshnessMin = 6,
    this.moveMeters = 75,
    this.useNative = true,
    this.useDeterrent = false,
    this.reassertLock = false,
    this.deterrentCooldownMin = 2,
  });

  SentryConfig copyWith({
    int? pollAwakeSec,
    int? freshnessMin,
    double? moveMeters,
    bool? useNative,
    bool? useDeterrent,
    bool? reassertLock,
    int? deterrentCooldownMin,
  }) =>
      SentryConfig(
        pollAwakeSec: pollAwakeSec ?? this.pollAwakeSec,
        freshnessMin: freshnessMin ?? this.freshnessMin,
        moveMeters: moveMeters ?? this.moveMeters,
        useNative: useNative ?? this.useNative,
        useDeterrent: useDeterrent ?? this.useDeterrent,
        reassertLock: reassertLock ?? this.reassertLock,
        deterrentCooldownMin: deterrentCooldownMin ?? this.deterrentCooldownMin,
      );

  Map<String, dynamic> toJson() => {
        'pollAwakeSec': pollAwakeSec,
        'freshnessMin': freshnessMin,
        'moveMeters': moveMeters,
        'useNative': useNative,
        'useDeterrent': useDeterrent,
        'reassertLock': reassertLock,
        'deterrentCooldownMin': deterrentCooldownMin,
      };

  factory SentryConfig.fromJson(Map<String, dynamic> j) => SentryConfig(
        pollAwakeSec: j['pollAwakeSec'] as int? ?? 30,
        freshnessMin: j['freshnessMin'] as int? ?? 6,
        moveMeters: (j['moveMeters'] as num?)?.toDouble() ?? 75,
        useNative: j['useNative'] as bool? ?? true,
        useDeterrent: j['useDeterrent'] as bool? ?? false,
        reassertLock: j['reassertLock'] as bool? ?? false,
        deterrentCooldownMin: j['deterrentCooldownMin'] as int? ?? 2,
      );
}
