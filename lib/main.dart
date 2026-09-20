import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/native/agent_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final flavor = await AgentBridge.flavor();
  runApp(EarGuardApp(role: _roleFor(flavor)));
}

AppRole? _roleFor(String flavor) => switch (flavor) {
  'agent' => AppRole.agent,
  'manager' => AppRole.manager,
  _ => null,
};
