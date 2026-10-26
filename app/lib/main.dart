import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/audio_handler.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Modern transparent edge-to-edge system bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize API service (loads saved token & backend URL)
  final apiService = ApiService();
  await apiService.init();

  // Initialize Android background audio service
  final audioHandler = await initAudioHandler();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: apiService),
        ChangeNotifierProvider.value(value: audioHandler as YunoAudioHandler),
      ],
      child: const YunoApp(),
    ),
  );
}

class YunoApp extends StatelessWidget {
  const YunoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = context.watch<ApiService>();

    return MaterialApp(
      title: 'Yuno Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: apiService.isAuthenticated ? const MainScreen() : const AuthScreen(),
    );
  }
}
