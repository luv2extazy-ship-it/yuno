import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/audio_handler.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';
import '../widgets/track_tile.dart';
import '../widgets/source_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Track> _trending = [];
  List<Map<String, dynamic>> _shelves = [];

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getFeed();
    if (mounted) {
      setState(() {
        _trending = data['trending'] as List<Track>;
        _shelves = data['shelves'] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = context.read<YunoAudioHandler>();
    final currentPlayingTrack = context.watch<YunoAudioHandler>().currentTrack;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _fetchFeed,
          child: CustomScrollView(
            slivers: [
              // Top Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/logo.jpg',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Yuno',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else ...[
                // Trending Charts Shelf
                if (_trending.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Тренды и чарты',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _trending.length,
                        itemBuilder: (context, index) {
                          final track = _trending[index];
                          return GestureDetector(
                            onTap: () => audioHandler.playTrack(track, queue: _trending),
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Artwork Card
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 140,
                                          height: 140,
                                          child: track.artworkUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: track.artworkUrl!,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => Container(
                                                    color: AppColors.surfaceElevated,
                                                    child: const Icon(LucideIcons.music, size: 36, color: AppColors.textMuted),
                                                  ),
                                                )
                                              : Container(
                                                  color: AppColors.surfaceElevated,
                                                  child: const Icon(LucideIcons.music, size: 36, color: AppColors.textMuted),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: SourceBadge(source: track.source),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Shelves by Genre / Mood
                for (var shelf in _shelves) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        shelf['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final track = (shelf['items'] as List<Track>)[idx];
                        return TrackTile(
                          track: track,
                          isPlaying: currentPlayingTrack?.id == track.id,
                          onTap: () => audioHandler.playTrack(track, queue: shelf['items']),
                        );
                      },
                      childCount: (shelf['items'] as List<Track>).length,
                    ),
                  ),
                ],

                // Bottom Padding for floating miniplayer
                const SliverToBoxAdapter(
                  child: SizedBox(height: 90),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
