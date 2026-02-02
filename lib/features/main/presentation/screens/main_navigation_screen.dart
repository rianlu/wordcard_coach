import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/home/presentation/screens/home_dashboard_screen.dart';
import '../../../../features/dictionary/presentation/screens/dictionary_screen.dart';
import 'package:wordcard_coach/features/statistics/presentation/screens/statistics_screen.dart';
import '../../../../features/mine/presentation/screens/mine_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  Key _statsKey = UniqueKey(); // Key to force refresh

  List<Widget> get _screens => [
    const HomeDashboardScreen(),
    const DictionaryScreen(),
    StatisticsScreen(key: _statsKey),
    const MineScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
          boxShadow: [
             BoxShadow(
               color: Colors.black12,
               offset: Offset(0, -4),
               blurRadius: 16,
             )
          ]
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 2) {
               // Force refresh of Statistics screen
               _statsKey = UniqueKey();
            }
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMediumEmphasis,
          selectedLabelStyle: const TextStyle(
             fontWeight: FontWeight.w900, 
             fontSize: 10, 
             letterSpacing: 0.5
          ),
          unselectedLabelStyle: const TextStyle(
             fontWeight: FontWeight.w900, 
             fontSize: 10, 
             letterSpacing: 0.5
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories),
              label: '学习',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), // Dictionary icon
              label: '词典',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: '分析',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
