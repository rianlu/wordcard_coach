import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/home/presentation/screens/home_dashboard_screen.dart';
import '../../../../features/collection/presentation/screens/collection_gallery_screen.dart';
import 'package:wordcard_coach/features/statistics/presentation/screens/statistics_screen.dart';
import '../../../../features/mine/presentation/screens/mine_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeDashboardScreen(),
    const CollectionGalleryScreen(),
    const StatisticsScreen(),
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
              icon: Icon(Icons.image), // grid_view in HTML, but image is close. Let's use grid_view if available in material
              label: '图鉴',
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
