import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/audio_handler.dart';
import '../services/api_service.dart';
import '../models/lyrics.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';

class LyricsScreen extends StatefulWidget {
  final Track track;

  const LyricsScreen({super.key, required this.track});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  LyricsData? _lyricsData;
  bool _isLoading = true;
  int _activeLineIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getLyrics(
      widget.track.title,
      widget.track.artist,
      album: widget.track.album,
      durationS: widget.track.durationMs > 0 ? (widget.track.durationMs ~/ 1000) : null,
    );
    if (mounted) {
      setState(() {
        _lyricsData = data;
        _isLoading = false;
      });
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || index < 0) return;
    // Estimate offset: ~60px per line
    final targetOffset = (index * 64.0) - 180.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = context.watch<YunoAudioHandler>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'КАРАОКЕ ТЕКСТ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronDown, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _lyricsData == null || (_lyricsData!.lines.isEmpty && (_lyricsData!.plainLyrics == null || _lyricsData!.plainLyrics!.isEmpty))
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.fileQuestion, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      const Text(
                        'Слова для этого трека не найдены',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: const Text('Повторить поиск'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loadLyrics,
                      ),
                    ],
                  ),
                )
              : !_lyricsData!.synced
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Text(
                        _lyricsData!.plainLyrics ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.8,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : StreamBuilder<Duration>(
                      stream: audioHandler.positionStream,
                      builder: (context, snapshot) {
                        final currentMs = snapshot.data?.inMilliseconds ?? 0;
                        final lines = _lyricsData!.lines;

                        // Find active line
                        int newIndex = -1;
                        for (int i = 0; i < lines.length; i++) {
                          if (currentMs >= lines[i].timestampMs) {
                            newIndex = i;
                          } else {
                            break;
                          }
                        }

                        if (newIndex != _activeLineIndex) {
                          _activeLineIndex = newIndex;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToIndex(_activeLineIndex);
                          });
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                          itemCount: lines.length,
                          itemBuilder: (context, index) {
                            final line = lines[index];
                            final isActive = index == _activeLineIndex;
                            final isPassed = index < _activeLineIndex;

                            return GestureDetector(
                              onTap: () {
                                audioHandler.seek(Duration(milliseconds: line.timestampMs));
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  line.text.isEmpty ? '♪' : line.text,
                                  style: TextStyle(
                                    fontSize: isActive ? 24 : 19,
                                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                    height: 1.4,
                                    color: isActive
                                        ? Colors.white
                                        : isPassed
                                            ? AppColors.textSecondary.withValues(alpha: 0.5)
                                            : AppColors.textMuted.withValues(alpha: 0.4),
                                    shadows: isActive
                                        ? [
                                            Shadow(
                                              color: AppColors.primary.withValues(alpha: 0.6),
                                              blurRadius: 16,
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}
