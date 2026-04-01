import 'package:flutter/material.dart';
import '../../../associations/presentation/screens/associations_screen.dart';
import '../../../events/presentation/screens/events_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';
import '../widgets/main_bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _screens = [
    EventsScreen(),
    ScheduleScreen(),
    AssociationsScreen(),
    ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey<int>(_currentIndex),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Transform.scale(
            scale: 0.97 + 0.03 * t,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
