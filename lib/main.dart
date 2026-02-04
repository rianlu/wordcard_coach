import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/services/backup_service.dart';
import 'features/main/presentation/screens/main_navigation_screen.dart';
import 'features/home/presentation/screens/home_dashboard_screen.dart';
import 'features/practice/presentation/screens/word_selection_screen.dart';
import 'features/practice/presentation/screens/speaking_practice_screen.dart';
import 'features/practice/presentation/screens/spelling_practice_screen.dart';
import 'features/battle/presentation/screens/boss_battle_matching_screen.dart';
import 'features/battle/presentation/screens/boss_battle_speaking_screen.dart';
import 'features/battle/presentation/screens/boss_battle_spelling_screen.dart';
import 'features/collection/presentation/screens/collection_gallery_screen.dart';
import 'features/statistics/presentation/screens/statistics_screen.dart';

import 'core/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper().database;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _channel = MethodChannel('com.example.wordcard_coach/file_handler');
  static const _eventChannel = EventChannel('com.example.wordcard_coach/file_handler/events');
  
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initFileHandler();
  }

  Future<void> _initFileHandler() async {
    // Listen for file shares while app is running
    _eventChannel.receiveBroadcastStream().listen((dynamic filePath) {
      if (filePath != null && filePath is String && filePath.isNotEmpty) {
        _handleSharedFile(filePath);
      }
    });

    // Check for initial shared file (app opened via file share)
    try {
      final String? initialFile = await _channel.invokeMethod('getInitialSharedFile');
      if (initialFile != null && initialFile.isNotEmpty) {
        // Delay to ensure UI is ready
        await Future.delayed(const Duration(milliseconds: 800));
        _handleSharedFile(initialFile);
      }
    } catch (e) {
      debugPrint('Error getting initial shared file: $e');
    }
  }

  void _handleSharedFile(String filePath) {
    debugPrint('Received shared file: $filePath');
    
    // Validate file extension
    if (!filePath.endsWith('.wcc') && !filePath.endsWith('.json')) {
      debugPrint('Invalid file type: $filePath');
      return;
    }

    // Get current context and import
    final context = _navigatorKey.currentState?.overlay?.context;
    if (context != null) {
      BackupService().importDataFromFile(File(filePath), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'WordCard Coach',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const MainNavigationScreen(),
        '/practice/selection': (context) => const WordSelectionScreen(),
        '/practice/speaking': (context) => const SpeakingPracticeScreen(),
        '/practice/spelling': (context) => const SpellingPracticeScreen(),
        '/battle/matching': (context) => const BossBattleMatchingScreen(),
        '/battle/speaking': (context) => const BossBattleSpeakingScreen(),
        '/battle/spelling': (context) => const BossBattleSpellingScreen(),
        '/collection': (context) => const CollectionGalleryScreen(),
        '/statistics': (context) => const StatisticsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
