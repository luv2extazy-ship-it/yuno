import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/audio_handler.dart';
import '../models/track.dart';
import '../theme/app_colors.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<Track> _allResults = [];
  String _selectedFilter = 'Все';
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    if (mounted) {
      setState(() => _searchHistory = list);
    }
  }

  Future<void> _saveHistory(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(_searchHistory);
    list.remove(clean);
    list.insert(0, clean);
    if (list.length > 12) {
      list.removeRange(12, list.length);
    }

    await prefs.setStringList('search_history', list);
    if (mounted) {
      setState(() => _searchHistory = list);
    }
  }

  Future<void> _deleteHistoryItem(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(_searchHistory);
    list.remove(query);
    await prefs.setStringList('search_history', list);
    if (mounted) {
      setState(() => _searchHistory = list);
    }
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (mounted) {
      setState(() => _searchHistory = []);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _allResults = [];
        _isLoading = false;
      });
      return;
    }

    _saveHistory(clean);
    setState(() => _isLoading = true);
    final results = await ApiService().search(clean);
    if (mounted) {
      setState(() {
        _allResults = results;
        _isLoading = false;
      });
    }
  }

  List<Track> get _filteredResults {
    if (_selectedFilter == 'Все') return _allResults;
    if (_selectedFilter == 'SoundCloud') {
      return _allResults.where((t) => t.source == 'soundcloud').toList();
    }
    if (_selectedFilter == 'YouTube') {
      return _allResults.where((t) => t.source == 'youtube').toList();
    }
    if (_selectedFilter == 'Spotify') {
      return _allResults.where((t) => t.source == 'spotify').toList();
    }
    return _allResults;
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = context.read<YunoAudioHandler>();
    final currentPlayingTrack = context.watch<YunoAudioHandler>().currentTrack;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _performSearch,
                  autofocus: false,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Что хотите послушать?',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    prefixIcon: const Icon(LucideIcons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // Filter Tabs (only when search has results)
            if (_allResults.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: ['Все', 'SoundCloud', 'YouTube', 'Spotify'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() => _selectedFilter = filter);
                        },
                        backgroundColor: AppColors.surfaceElevated,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Content Area: Results, History, or Empty state
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _searchController.text.isNotEmpty
                      ? _filteredResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(LucideIcons.frown, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'По вашему запросу ничего не найдено',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 90),
                              itemCount: _filteredResults.length,
                              itemBuilder: (context, index) {
                                final track = _filteredResults[index];
                                return TrackTile(
                                  track: track,
                                  isPlaying: currentPlayingTrack?.id == track.id,
                                  onTap: () {
                                    audioHandler.playTrack(track, queue: _filteredResults);
                                  },
                                );
                              },
                            )
                      : _searchHistory.isNotEmpty
                          ? ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'История поиска',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _clearHistory,
                                      child: const Text(
                                        'Очистить',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._searchHistory.map((item) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(LucideIcons.history, size: 18, color: AppColors.textSecondary),
                                    title: Text(
                                      item,
                                      style: const TextStyle(fontSize: 15, color: Colors.white),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textSecondary),
                                      onPressed: () => _deleteHistoryItem(item),
                                    ),
                                    onTap: () {
                                      _searchController.text = item;
                                      _performSearch(item);
                                    },
                                  );
                                }),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(LucideIcons.search, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Найдите треки из Spotify, SoundCloud и YouTube',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
