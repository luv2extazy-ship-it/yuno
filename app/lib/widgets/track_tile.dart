import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';
import 'source_badge.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const TrackTile({
    super.key,
    required this.track,
    this.isPlaying = false,
    required this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: track.artworkUrl != null && track.artworkUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.surfaceElevated,
                          child: const Icon(LucideIcons.music, size: 20, color: AppColors.textMuted),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.surfaceElevated,
                          child: const Icon(LucideIcons.music, size: 20, color: AppColors.textMuted),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceElevated,
                        child: const Icon(LucideIcons.music, size: 20, color: AppColors.textMuted),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Track Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPlaying ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SourceBadge(source: track.source),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isPlaying)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(LucideIcons.volume2, size: 18, color: AppColors.primary),
              ),
            if (onMore != null)
              IconButton(
                icon: const Icon(LucideIcons.moreVertical, size: 18, color: AppColors.textSecondary),
                onPressed: onMore,
              ),
          ],
        ),
      ),
    );
  }
}
