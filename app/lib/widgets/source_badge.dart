import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SourceBadge extends StatelessWidget {
  final String source;

  const SourceBadge({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;

    switch (source.toLowerCase()) {
      case 'soundcloud':
        bg = AppColors.soundcloud;
        label = 'SoundCloud';
        break;
      case 'youtube':
        bg = AppColors.youtube;
        label = 'YouTube';
        break;
      case 'spotify':
        bg = AppColors.spotify;
        label = 'Spotify';
        break;
      default:
        bg = Colors.grey.shade700;
        label = source.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: bg.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bg,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
