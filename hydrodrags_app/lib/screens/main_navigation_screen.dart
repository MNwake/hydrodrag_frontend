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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      InfoTabScreen(
        onPurchaseSpectatorTickets: () => setState(() => _currentIndex = 1),
      ),
      const EventsTabScreen(),
      const LiveBracketsTabScreen(),
      const AccountManagementTabScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
