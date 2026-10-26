import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'api_service.dart';

Future<AudioHandler> initAudioHandler() async {
  return await AudioService.init(
    builder: () => YunoAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.yuno.music.channel.audio',
      androidNotificationChannelName: 'Yuno Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class YunoAudioHandler extends BaseAudioHandler with SeekHandler, ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = 0;

  Track? get currentTrack => _currentTrack;
  List<Track> get tracksQueue => _queue;
  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get isPlayingStream => _player.playingStream;

  YunoAudioHandler() {
    _init();
  }

  void _init() {
    // 1. Forward player events to AudioService playbackState
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });

    // 2. Auto-advance when track finishes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    _currentTrack = track;
    if (queue != null && queue.isNotEmpty) {
      _queue = List.from(queue);
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      }
    } else {
      _queue = [track];
      _currentIndex = 0;
    }

    final fullStreamUrl = ApiService().getStreamUrl(track.id);

    // Update system notification MediaItem
    final item = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album ?? 'Yuno Music',
      duration: track.durationMs > 0 ? Duration(milliseconds: track.durationMs) : null,
      artUri: track.artworkUrl != null ? Uri.parse(track.artworkUrl!) : null,
    );
    mediaItem.add(item);
    notifyListeners();

    try {
      await _player.setUrl(fullStreamUrl);
      await _player.play();
      ApiService().recordHistory(track);
    } catch (e) {
      debugPrint('Playback error for ${track.id}: $e');
    }
  }

  @override
  Future<void> play() async => await _player.play();

  @override
  Future<void> pause() async => await _player.pause();

  @override
  Future<void> seek(Duration position) async => await _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex], queue: _queue);
    } else if (_currentTrack != null) {
      // Loop or fetch radio recommendation
      await seek(Duration.zero);
      await play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex], queue: _queue);
    } else {
      await seek(Duration.zero);
    }
  }
}
