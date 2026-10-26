class Track {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
  final String? artworkUrl;
  final String source; // youtube, soundcloud, spotify
  final String streamUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs = 0,
    this.artworkUrl,
    required this.source,
    required this.streamUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] ?? json['track_id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'],
      durationMs: json['duration_ms'] ?? 0,
      artworkUrl: json['artwork_url'],
      source: json['source'] ?? 'unknown',
      streamUrl: json['stream_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track_id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_ms': durationMs,
      'artwork_url': artworkUrl,
      'source': source,
      'stream_url': streamUrl,
    };
  }
}
