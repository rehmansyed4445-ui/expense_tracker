import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/session_gate.dart';
import 'screens/sign_in_screen.dart';
import 'services/auth_service.dart';
import 'services/storage.dart';
import 'state/expense_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final storage = TransactionStorage();
  await storage.migrateFromPrefsIfNeeded();

  final store = ExpenseStore(storage);
  await store.load();
  await store.prepareSyncSafety();

  final auth = AuthService();
  await auth.initialize();

  runApp(ExpenseApp(store: store, auth: auth));
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({super.key, required this.store, required this.auth});
  final ExpenseStore store;
  final AuthService auth;

  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() => setState(() {});

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFFFDF5),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expenses',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      themeMode: ThemeMode.light,
      home: widget.auth.canAccessApp
          ? SessionGate(store: widget.store, auth: widget.auth)
          : SignInScreen(auth: widget.auth),
    );
  }
}
