import 'package:flutter/material.dart';

import 'screens/agent_screen.dart';
import 'screens/devices_screen.dart';

enum AppRole { agent, manager }

class EarGuardApp extends StatelessWidget {
  const EarGuardApp({super.key, this.role});

  final AppRole? role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EarGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: switch (role) {
        AppRole.agent => const AgentScreen(),
        AppRole.manager => const DevicesScreen(),
        null => const _DualHome(),
      },
    );
  }
}

class _DualHome extends StatefulWidget {
  const _DualHome();

  @override
  State<_DualHome> createState() => _DualHomeState();
}

class _DualHomeState extends State<_DualHome> {
  int _index = 0;

  static const List<Widget> _pages = [DevicesScreen(), AgentScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.devices), label: 'Devices'),
          NavigationDestination(
            icon: Icon(Icons.settings_remote),
            label: 'This device',
          ),
        ],
      ),
    );
  }
}
