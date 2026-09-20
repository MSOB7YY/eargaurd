class Analysis {
  const Analysis({
    required this.sampleRate,
    required this.binHz,
    required this.bars,
    required this.peakHz,
    required this.peakDb,
    required this.bandPeakHz,
    required this.bandPeakDb,
  });

  final int sampleRate;
  final double binHz;
  final List<double> bars;
  final double peakHz;
  final double peakDb;
  final double bandPeakHz;
  final double bandPeakDb;

  double get nyquist => sampleRate / 2;

  factory Analysis.fromMap(Map<String, dynamic> j) => Analysis(
    sampleRate: (j['sampleRate'] ?? 44100) as int,
    binHz: ((j['binHz'] ?? 10.0) as num).toDouble(),
    bars: ((j['bars'] ?? const []) as List)
        .map((e) => (e as num).toDouble())
        .toList(growable: false),
    peakHz: ((j['peakHz'] ?? 0) as num).toDouble(),
    peakDb: ((j['peakDb'] ?? -120) as num).toDouble(),
    bandPeakHz: ((j['bandPeakHz'] ?? 0) as num).toDouble(),
    bandPeakDb: ((j['bandPeakDb'] ?? -120) as num).toDouble(),
  );
}
