import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        '/battle/spelling': (context) => const BossBattleSpellingScreen(),
        '/collection': (context) => const CollectionGalleryScreen(),
        '/statistics': (context) => const StatisticsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}



