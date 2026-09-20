class DeviceStatus {
  const DeviceStatus({
    required this.volume,
    required this.max,
    required this.cap,
    required this.capEnabled,
    required this.threshold,
    required this.micReady,
    this.name,
  });

  final int volume;
  final int max;
  final int cap;
  final bool capEnabled;
  final double threshold;
  final bool micReady;
  final String? name;

  factory DeviceStatus.fromJson(Map<String, dynamic> j) => DeviceStatus(
    volume: (j['volume'] ?? 0) as int,
    max: (j['max'] ?? 15) as int,
    cap: (j['cap'] ?? 8) as int,
    capEnabled: (j['capEnabled'] ?? false) as bool,
    threshold: ((j['threshold'] ?? -45) as num).toDouble(),
    micReady: (j['micReady'] ?? false) as bool,
    name: j['name'] as String?,
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
