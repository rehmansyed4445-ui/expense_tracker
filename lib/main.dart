import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/storage.dart';
import 'state/expense_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ExpenseStore(TransactionStorage());
  await store.load(); // never race the first save against the load
  runApp(ExpenseApp(store: store));
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key, required this.store});
  final ExpenseStore store;

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
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
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomeScreen(store: store),
    );
  }
}
