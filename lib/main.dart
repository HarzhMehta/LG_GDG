import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/ssh_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/lg_controller.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final settingsController = SettingsController();
  await settingsController.loadSettings();
  
  final sshController = SSHController();
  final lgController = LGController(
    sshController: sshController,
    settingsController: settingsController,
  );
  
  runApp(
    ProviderScope(
      child: MyApp(
        sshController: sshController,
        settingsController: settingsController,
        lgController: lgController,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SSHController sshController;
  final SettingsController settingsController;
  final LGController lgController;

  const MyApp({
    super.key,
    required this.sshController,
    required this.settingsController,
    required this.lgController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LG Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: HomeScreen(
        sshController: sshController,
        settingsController: settingsController,
        lgController: lgController,
      ),
    );
  }
}
