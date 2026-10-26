import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppColors.surface,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.home, size: 22),
            activeIcon: Icon(LucideIcons.home, size: 22, color: AppColors.primary),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.search, size: 22),
            activeIcon: Icon(LucideIcons.search, size: 22, color: AppColors.primary),
            label: 'Поиск',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.library, size: 22),
            activeIcon: Icon(LucideIcons.library, size: 22, color: AppColors.primary),
            label: 'Медиатека',
          ),
        ],
      ),
    );
  }
}
