import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'state.dart';
import 'theme.dart';
import 'screens/home.dart';
import 'screens/categories.dart';
import 'screens/category.dart';
import 'screens/account.dart';
import 'screens/wishlist.dart';

export 'theme.dart';
export 'widgets/top_bar.dart' show openBag;

final shellKey = GlobalKey<ShellState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light));
  final store = StoreState()..load();
  final bag = BagState()..load();
  final wish = WishState()..load();
  final acct = AccountState()..load();
  final recent = RecentState()..load();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: store),
    ChangeNotifierProvider.value(value: bag),
    ChangeNotifierProvider.value(value: wish),
    ChangeNotifierProvider.value(value: acct),
    ChangeNotifierProvider.value(value: recent),
  ], child: const PeachPiperApp()));
}

class PeachPiperApp extends StatelessWidget {
  const PeachPiperApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peach Piper',
      debugShowCheckedModeBanner: false,
      theme: ppTheme(),
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
    const pages = [HomeScreen(), CategoriesScreen(), CategoryScreen('', 'New arrivals', tab: true), WishlistScreen(tab: true), AccountScreen()];
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home', 0),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories', 0),
      (Icons.auto_awesome_outlined, Icons.auto_awesome, 'New In', 0),
      (Icons.favorite_border, Icons.favorite, 'Wishlist', 0),
      (Icons.person_outline, Icons.person, 'Account', 0),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkResponse(
                    onTap: () => go(i),
                    radius: 36,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Badge(
                        isLabelVisible: items[i].$4 > 0,
                        backgroundColor: coral,
                        label: Text('${items[i].$4}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        child: Icon(tab == i ? items[i].$2 : items[i].$1, color: tab == i ? wine : muted, size: 24),
                      ),
                      const SizedBox(height: 3),
                      Text(items[i].$3.toUpperCase(),
                          style: TextStyle(fontFamily: kSans, fontSize: 9.5, letterSpacing: 1.1, fontWeight: tab == i ? FontWeight.w800 : FontWeight.w600, color: tab == i ? wine : muted)),
                      const SizedBox(height: 3),
                      AnimatedContainer(duration: const Duration(milliseconds: 200), width: tab == i ? 18 : 0, height: 2, color: coral),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Switch the bottom tab from anywhere (e.g. "Go to bag").
void goTab(BuildContext context, int i) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  shellKey.currentState?.go(i);
}
