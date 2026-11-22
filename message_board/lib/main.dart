import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens.dart';
import 'services.dart';

const emulator = bool.fromEnvironment('USE_EMULATORS');
const rulesChecks = bool.fromEnvironment('RULES_CHECKS');
const emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startup = initializeWithSplash();
  runApp(VaultApp(startup: startup));
}

Future<({AuthService auth, BoardService board})> initializeWithSplash() async {
  final minimumSplash = Future<void>.delayed(const Duration(milliseconds: 900));
  final services = await initialize();
  await minimumSplash;
  return services;
}

Future<({AuthService auth, BoardService board})> initialize() async {
  const localOptions = FirebaseOptions(
    apiKey: 'demo-vault-hunt-key',
    appId: '1:1234567890:android:0123456789abcdef',
    messagingSenderId: '1234567890',
    projectId: 'demo-vault-hunt',
  );
  final app = await Firebase.initializeApp(
    name: emulator ? 'vault-local' : null,
    options: emulator ? localOptions : DefaultFirebaseOptions.currentPlatform,
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  final db = FirebaseFirestore.instanceFor(app: app);
  if (emulator) {
    await auth.useAuthEmulator(emulatorHost, 9099);
    db.useFirestoreEmulator(emulatorHost, 8080);
  }
  return (auth: AuthService(auth), board: BoardService(db));
}

class VaultApp extends StatefulWidget {
  const VaultApp({super.key, required this.startup});

  final Future<({AuthService auth, BoardService board})> startup;

  @override
  State<VaultApp> createState() => _VaultAppState();
}

class _VaultAppState extends State<VaultApp> {
  late var _startup = widget.startup;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Message Board Vault',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffa4d6b1),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff101a15),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: FutureBuilder(
      future: _startup,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services != null) {
          return AuthGate(
            auth: services.auth,
            board: services.board,
            rulesChecks: rulesChecks,
            emulator: emulator,
          );
        }
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 76,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Message Board Vault',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.hasError) ...[
                    const Text(
                      'Firebase could not start. Check the project configuration and try again.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _startup = initializeWithSplash()),
                      child: const Text('Retry'),
                    ),
                  ] else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
