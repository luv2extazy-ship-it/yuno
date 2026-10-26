import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/audio_handler.dart';
import '../services/api_service.dart';
import '../models/lyrics.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';
import '../widgets/source_badge.dart';
import 'lyrics_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isFavorite = false;
  LyricsData? _lyricsData;
  bool _isLoadingLyrics = false;
  String? _lastLoadedTrackId;

  void _checkAndLoadLyrics(Track track) {
    if (_lastLoadedTrackId == track.id) return;
    _lastLoadedTrackId = track.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLyrics(track));
  }

  Future<void> _loadLyrics(Track track) async {
    if (!mounted) return;
    setState(() {
      _isLoadingLyrics = true;
      _lyricsData = null;
    });
    try {
      final data = await ApiService().getLyrics(
        track.title,
        track.artist,
        album: track.album,
        durationS: track.durationMs > 0 ? (track.durationMs ~/ 1000) : null,
      );
      if (mounted && _lastLoadedTrackId == track.id) {
        setState(() {
          _lyricsData = data;
          _isLoadingLyrics = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = context.watch<YunoAudioHandler>();
    final track = audioHandler.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: const Center(child: Text('Нет активного трека')),
      );
    }

    _checkAndLoadLyrics(track);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronDown, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      const Text(
                        'ВОСПРОИЗВЕДЕНИЕ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.album ?? 'Yuno Music',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.moreVertical, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),
              const Spacer(flex: 1),

              // Large Artwork
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: track.artworkUrl != null
                        ? CachedNetworkImage(
                            imageUrl: track.artworkUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.surfaceElevated,
                              child: const Icon(LucideIcons.music, size: 64, color: AppColors.textMuted),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceElevated,
                            child: const Icon(LucideIcons.music, size: 64, color: AppColors.textMuted),
                          ),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Track Title, Artist & Favorite
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SourceBadge(source: track.source),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? LucideIcons.heart : LucideIcons.heart,
                      color: _isFavorite ? AppColors.primary : AppColors.textSecondary,
                      size: 26,
                    ),
                    onPressed: () async {
                      setState(() => _isFavorite = !_isFavorite);
                      final isFav = await ApiService().toggleFavorite(track);
                      setState(() => _isFavorite = isFav);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Progress Bar & Timestamps
              StreamBuilder<Duration>(
                stream: audioHandler.positionStream,
                builder: (context, posSnapshot) {
                  return StreamBuilder<Duration?>(
                    stream: audioHandler.durationStream,
                    builder: (context, durSnapshot) {
                      final pos = posSnapshot.data ?? Duration.zero;
                      final dur = durSnapshot.data ?? Duration(milliseconds: track.durationMs);

                      final maxVal = dur.inMilliseconds.toDouble();
                      final currentVal = pos.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayColor: AppColors.primary.withValues(alpha: 0.3),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: currentVal,
                              min: 0.0,
                              max: maxVal > 0 ? maxVal : 1.0,
                              onChanged: (val) {
                                audioHandler.seek(Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(pos), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(_formatDuration(dur), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.shuffle, size: 22, color: AppColors.textSecondary),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.skipBack, size: 30, color: Colors.white),
                    onPressed: () => audioHandler.skipToPrevious(),
                  ),
                  StreamBuilder<bool>(
                    stream: audioHandler.isPlayingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: Icon(
                            isPlaying ? LucideIcons.pause : LucideIcons.play,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.skipForward, size: 30, color: Colors.white),
                    onPressed: () => audioHandler.skipToNext(),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.repeat, size: 22, color: AppColors.textSecondary),
                    onPressed: () {},
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Spotify-style Live Karaoke Card
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LyricsScreen(track: track)),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryDark.withValues(alpha: 0.5),
                        AppColors.surfaceElevated,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.mic2, size: 16, color: AppColors.primaryLight),
                              const SizedBox(width: 8),
                              Text(
                                _lyricsData?.synced == true ? 'СИНХРОНИЗИРОВАННЫЙ ТЕКСТ' : 'ТЕКСТ ПЕСНИ',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const Icon(LucideIcons.maximize2, size: 15, color: AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<Duration>(
                        stream: audioHandler.positionStream,
                        builder: (context, snapshot) {
                          if (_isLoadingLyrics) {
                            return const Text(
                              'Поиск текста песни...',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            );
                          }
                          if (_lyricsData == null || (_lyricsData!.lines.isEmpty && (_lyricsData!.plainLyrics == null || _lyricsData!.plainLyrics!.isEmpty))) {
                            return const Text(
                              'Нажмите для просмотра караоке',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            );
                          }
                          if (_lyricsData!.synced && _lyricsData!.lines.isNotEmpty) {
                            final currentMs = (snapshot.data ?? Duration.zero).inMilliseconds;
                            int activeIdx = -1;
                            for (int i = 0; i < _lyricsData!.lines.length; i++) {
                              if (currentMs >= _lyricsData!.lines[i].timestampMs) {
                                activeIdx = i;
                              } else {
                                break;
                              }
                            }
                            final activeLine = activeIdx >= 0 ? _lyricsData!.lines[activeIdx].text : _lyricsData!.lines.first.text;
                            final nextLine = (activeIdx + 1 < _lyricsData!.lines.length)
                                ? _lyricsData!.lines[activeIdx + 1].text
                                : '';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeLine.isNotEmpty ? activeLine : '♪',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (nextLine.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    nextLine,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            );
                          } else {
                            return Text(
                              _lyricsData!.plainLyrics ?? 'Текст песни',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
