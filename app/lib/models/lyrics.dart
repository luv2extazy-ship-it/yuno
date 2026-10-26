class LyricLine {
  final int timestampMs;
  final String timeTag;
  final String text;

  LyricLine({
    required this.timestampMs,
    required this.timeTag,
    required this.text,
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      timestampMs: json['timestamp_ms'] ?? 0,
      timeTag: json['time_tag'] ?? '',
      text: json['text'] ?? '',
    );
  }
}

class LyricsData {
  final String trackName;
  final String artistName;
  final bool synced;
  final String? plainLyrics;
  final List<LyricLine> lines;

  LyricsData({
    required this.trackName,
    required this.artistName,
    required this.synced,
    this.plainLyrics,
    required this.lines,
  });

  factory LyricsData.fromJson(Map<String, dynamic> json) {
    var rawLines = json['lines'] as List? ?? [];
    List<LyricLine> parsedLines = rawLines.map((e) => LyricLine.fromJson(e)).toList();

    return LyricsData(
      trackName: json['track_name'] ?? '',
      artistName: json['artist_name'] ?? '',
      synced: json['synced'] ?? false,
      plainLyrics: json['plain_lyrics'],
      lines: parsedLines,
    );
  }
}
