import 'track.dart';

class PlaylistModel {
  final String id;
  final String title;
  final String? description;
  final String? coverUrl;
  final bool isPublic;
  final List<Track> tracks;

  PlaylistModel({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    this.isPublic = true,
    this.tracks = const [],
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    var rawTracks = json['tracks'] as List? ?? [];
    List<Track> parsedTracks = rawTracks.map((t) => Track.fromJson(t)).toList();

    return PlaylistModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Playlist',
      description: json['description'],
      coverUrl: json['cover_url'],
      isPublic: json['is_public'] ?? true,
      tracks: parsedTracks,
    );
  }
}
