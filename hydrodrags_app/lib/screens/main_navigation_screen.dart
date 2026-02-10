import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'info_tab_screen.dart';
import 'events_tab_screen.dart';
import 'live_brackets_tab_screen.dart';
import 'account_management_tab_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  static const int _resultsTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final l10n = AppLocalizations.of(context);

    final screens = [
      InfoTabScreen(
        onPurchaseSpectatorTickets: () => setState(() => _currentIndex = 1),
      ),
      const EventsTabScreen(),
      KeyedSubtree(
        key: const ValueKey('results_tab'),
        child: LiveBracketsTabScreen(isTabSelected: _currentIndex == _resultsTabIndex),
      ),
      const AccountManagementTabScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Events',
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events),
            label: l10n?.resultsTab ?? 'Results',
          ),
          NavigationDestination(
            icon: Icon(authService.isAuthenticated ? Icons.person_outline : Icons.lock_outline),
            selectedIcon: Icon(authService.isAuthenticated ? Icons.person : Icons.lock),
            label: authService.isAuthenticated ? 'Account' : 'Login',
          ),
        ],
      ),
    );
  }
}
