import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/trip_repository.dart';
import 'screens/export_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'de_DE';
  await initializeDateFormatting('de_DE');
  final repository = TripRepository(await SharedPreferences.getInstance());
  runApp(MunichCounterApp(repository: repository));
}

class MunichCounterApp extends StatelessWidget {
  const MunichCounterApp({super.key, required this.repository});

  final TripRepository repository;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: brightness,
          ),
          fontFamily: 'Roboto',
          useMaterial3: true,
        );

    return MaterialApp(
      title: 'Munich Counter',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(repository: repository),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository});

  final TripRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        repository: widget.repository,
        onShowHistory: () => setState(() => _tab = 1),
      ),
      HistoryScreen(repository: widget.repository),
      ExportScreen(repository: widget.repository),
    ];

    // In an iOS home-screen web app the home indicator overlaps the page,
    // but Flutter web reports no safe-area inset, so reserve space manually.
    final bottomInset = defaultTargetPlatform == TargetPlatform.iOS &&
            MediaQuery.paddingOf(context).bottom == 0
        ? 16.0
        : 0.0;

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Start',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Verlauf',
              ),
              NavigationDestination(
                icon: Icon(Icons.ios_share_outlined),
                selectedIcon: Icon(Icons.ios_share),
                label: 'Export',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
