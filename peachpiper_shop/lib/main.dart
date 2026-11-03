import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state.dart';
import 'screens/home.dart';
import 'screens/categories.dart';
import 'screens/bag.dart';
import 'screens/account.dart';
import 'screens/search.dart';

const wine = Color(0xFF5B1E2D);
const coral = Color(0xFFFF767B);
const ink = Color(0xFF1E1A1D);
const muted = Color(0xFF6E6670);
const line = Color(0xFFE6E4E8);
const blush = Color(0xFFFFF0EE);
final shellKey = GlobalKey<ShellState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = StoreState()..load();
  final bag = BagState()..load();
  final wish = WishState()..load();
  final acct = AccountState()..load();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: store),
    ChangeNotifierProvider.value(value: bag),
    ChangeNotifierProvider.value(value: wish),
    ChangeNotifierProvider.value(value: acct),
  ], child: const PeachPiperApp()));
}

class PeachPiperApp extends StatelessWidget {
  const PeachPiperApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: wine, primary: wine, secondary: coral, surface: Colors.white));
    return MaterialApp(
      title: 'Peach Piper',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFFAF7F6),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0.5, centerTitle: false,
            titleTextStyle: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: wine, minimumSize: const Size(48, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: wine, minimumSize: const Size(48, 50), side: const BorderSide(color: wine, width: 1.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: line)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
        chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
      ),
      home: Shell(key: shellKey),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int tab = 0;
  void go(int i) => setState(() => tab = i);
  @override
  Widget build(BuildContext context) {
    final bag = context.watch<BagState>();
    final pages = const [HomeScreen(), CategoriesScreen(), SearchScreen(), BagScreen(), AccountScreen()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        height: 64,
        backgroundColor: Colors.white,
        indicatorColor: blush,
        onDestinationSelected: go,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: wine), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view, color: wine), label: 'Shop'),
          const NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
              icon: Badge(isLabelVisible: bag.count > 0, label: Text('${bag.count}'), backgroundColor: coral, child: const Icon(Icons.shopping_bag_outlined)),
              selectedIcon: Badge(isLabelVisible: bag.count > 0, label: Text('${bag.count}'), backgroundColor: coral, child: const Icon(Icons.shopping_bag, color: wine)),
              label: 'Bag'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: wine), label: 'Account'),
        ],
      ),
    );
  }
}

/// Switch the bottom tab from anywhere (e.g. "Go to bag").
void goTab(BuildContext context, int i) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  shellKey.currentState?.go(i);
}
