class DeviceStatus {
  const DeviceStatus({
    required this.volume,
    required this.max,
    required this.cap,
    required this.capEnabled,
    required this.threshold,
    required this.minHz,
    required this.maxHz,
    required this.micReady,
    this.name,
  });

  final int volume;
  final int max;
  final int cap;
  final bool capEnabled;
  final double threshold;
  final int minHz;
  final int maxHz;
  final bool micReady;
  final String? name;

  factory DeviceStatus.fromJson(Map<String, dynamic> j) => DeviceStatus(
    volume: (j['volume'] ?? 0) as int,
    max: (j['max'] ?? 15) as int,
    cap: (j['cap'] ?? 8) as int,
    capEnabled: (j['capEnabled'] ?? false) as bool,
    threshold: ((j['threshold'] ?? -45) as num).toDouble(),
    minHz: (j['minHz'] ?? 8000) as int,
    maxHz: (j['maxHz'] ?? 20000) as int,
    micReady: (j['micReady'] ?? false) as bool,
    name: j['name'] as String?,
  );

  DeviceStatus copyWith({int? volume, int? cap, bool? capEnabled}) =>
      DeviceStatus(
        volume: volume ?? this.volume,
        max: max,
        cap: cap ?? this.cap,
        capEnabled: capEnabled ?? this.capEnabled,
        threshold: threshold,
        minHz: minHz,
        maxHz: maxHz,
        micReady: micReady,
        name: name,
      );
}

class Device {
  const Device({
    required this.name,
    required this.host,
    required this.port,
    this.manual = false,
  });

  final String name;
  final String host;
  final int port;
  final bool manual;

  String get id => '$host:$port';
  String get base => 'http://$host:$port';
}
