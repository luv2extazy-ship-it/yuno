import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/audio_handler.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../theme/app_colors.dart';
import '../widgets/track_tile.dart';
import 'auth_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Track> _favorites = [];
  List<PlaylistModel> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = ApiService();
    final favs = await api.getFavorites();
    final pls = await api.getPlaylists();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _playlists = pls;
        _isLoading = false;
      });
    }
  }

  void _showCreatePlaylistDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Новый плейлист', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Описание (необязательно)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Создать', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                await ApiService().createPlaylist(titleController.text.trim(), description: descController.text.trim());
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final urlController = TextEditingController(text: ApiService().baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Настройки сервера Yuno', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Адрес бэкенда:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'http://10.0.2.2:8000 или http://192.168.1.X:8000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Сохранить', style: TextStyle(color: AppColors.primary)),
            onPressed: () {
              ApiService().setBaseUrl(urlController.text.trim());
              Navigator.of(context).pop();
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final audioHandler = context.read<YunoAudioHandler>();
    final currentPlayingTrack = context.watch<YunoAudioHandler>().currentTrack;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // User Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      api.currentUser?.username.isNotEmpty == true ? api.currentUser!.username[0].toUpperCase() : 'Y',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          api.currentUser?.username ?? 'Пользователь Yuno',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        Text(
                          api.currentUser?.email ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.settings, size: 20, color: AppColors.textSecondary),
                    onPressed: _showSettingsDialog,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.logOut, size: 20, color: AppColors.textSecondary),
                    onPressed: () async {
                      await api.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Любимые треки'),
                Tab(text: 'Плейлисты'),
              ],
            ),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. Favorites Tab
                        _favorites.isEmpty
                            ? const Center(
                                child: Text('Вы пока не добавили любимых треков', style: TextStyle(color: AppColors.textSecondary)),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 90),
                                itemCount: _favorites.length,
                                itemBuilder: (context, index) {
                                  final track = _favorites[index];
                                  return TrackTile(
                                    track: track,
                                    isPlaying: currentPlayingTrack?.id == track.id,
                                    onTap: () => audioHandler.playTrack(track, queue: _favorites),
                                  );
                                },
                              ),

                        // 2. Playlists Tab
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: OutlinedButton.icon(
                                icon: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
                                label: const Text('Создать плейлист', style: TextStyle(color: Colors.white)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: _showCreatePlaylistDialog,
                              ),
                            ),
                            Expanded(
                              child: _playlists.isEmpty
                                  ? const Center(
                                      child: Text('У вас пока нет созданных плейлистов', style: TextStyle(color: AppColors.textSecondary)),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(bottom: 90),
                                      itemCount: _playlists.length,
                                      itemBuilder: (context, index) {
                                        final pl = _playlists[index];
                                        return ListTile(
                                          leading: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceElevated,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(LucideIcons.listMusic, color: AppColors.primary),
                                          ),
                                          title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                          subtitle: Text('${pl.tracks.length} треков', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                                          onTap: () {},
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
