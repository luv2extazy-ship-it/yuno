import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_colors.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioHandler = context.watch<YunoAudioHandler>();
    final currentTrack = audioHandler.currentTrack;

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, anim, secondaryAnim) => const PlayerScreen(),
            transitionsBuilder: (context, anim, secondaryAnim, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: anim.drive(tween), child: child);
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress hairline
              StreamBuilder<Duration>(
                stream: audioHandler.positionStream,
                builder: (context, posSnapshot) {
                  return StreamBuilder<Duration?>(
                    stream: audioHandler.durationStream,
                    builder: (context, durSnapshot) {
                      final pos = posSnapshot.data?.inMilliseconds ?? 0;
                      final dur = durSnapshot.data?.inMilliseconds ?? currentTrack.durationMs;
                      final progress = (dur > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      );
                    },
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: currentTrack.artworkUrl != null
                            ? CachedNetworkImage(
                                imageUrl: currentTrack.artworkUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.surface,
                                  child: const Icon(LucideIcons.music, size: 20, color: AppColors.textMuted),
                                ),
                              )
                            : Container(
                                color: AppColors.surface,
                                child: const Icon(LucideIcons.music, size: 20, color: AppColors.textMuted),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Track & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTrack.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentTrack.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Play/Pause button
                    StreamBuilder<bool>(
                      stream: audioHandler.isPlayingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            isPlaying ? LucideIcons.pause : LucideIcons.play,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                        );
                      },
                    ),
                    // Skip Next
                    IconButton(
                      icon: const Icon(
                        LucideIcons.skipForward,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => audioHandler.skipToNext(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
