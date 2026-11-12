import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initError;
  if (AppConfig.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseSenderId,
          projectId: AppConfig.firebaseProjectId,
          storageBucket: '${AppConfig.firebaseProjectId}.firebasestorage.app',
        ),
      );
    } catch (e) {
      initError = '$e';
    }
  } else {
    initError = 'Firebase ayarları henüz girilmedi (lib/config.dart).';
  }
  runApp(BegeniAviApp(initError: initError));
}

class BegeniAviApp extends StatelessWidget {
  const BegeniAviApp({super.key, this.initError});
  final String? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beğeni Avı',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: initError != null ? _SetupError(message: initError!) : const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 64, color: AppColors.pink),
            const SizedBox(height: 16),
            const Text('Sunucuya bağlanılamadı',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}
