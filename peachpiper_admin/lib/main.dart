import 'package:flutter/material.dart';
import 'api.dart';
import 'orders.dart';
import 'inbox.dart';

const wine = Color(0xFF5B1E2D);
const attn = Color(0xFFE9A23B);
const ink = Color(0xFF1E1A1D);
const muted = Color(0xFF6E6670);
const line = Color(0xFFE6E4E8);
final navKey = GlobalKey<NavigatorState>();

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peach Piper Admin',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: wine, primary: wine),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: ink, scrolledUnderElevation: 0.5),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: wine, minimumSize: const Size(48, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      ),
      home: const Boot(),
    );
  }
}

/// Session expired anywhere → back to the login screen.
void toLogin() => navKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);

void showErr(BuildContext context, Object e) {
  if (e is ApiError && e.auth) return toLogin();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFB3262E)));
}

class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  @override
  void initState() {
    super.initState();
    Api.I.restore().then((ok) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ok ? const Home() : const LoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: wine)));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false;
  String? err;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 40),
          Center(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/icon.png', width: 76))),
          const SizedBox(height: 16),
          const Center(child: Text('Peach Piper Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          const SizedBox(height: 28),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: Color(0xFFB3262E)))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      err = null;
                    });
                    try {
                      await Api.I.login(email.text.trim(), pass.text);
                      if (!context.mounted) return;
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
                    } catch (e) {
                      setState(() => err = e.toString());
                    }
                    if (mounted) setState(() => busy = false);
                  },
            child: const Text('Log in'),
          ),
        ]),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tab, children: const [Today(), OrdersScreen(), InboxScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: Colors.white,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.mail_outline), label: 'Inbox'),
        ],
      ),
    );
  }
}

/// "Needs you today" + today's numbers, like the web dashboard.
class Today extends StatefulWidget {
  const Today({super.key});
  @override
  State<Today> createState() => _TodayState();
}

class _TodayState extends State<Today> {
  Map<String, dynamic>? me, dash;
  Future<void> load() async {
    try {
      final r = await Future.wait([Api.I.get('me'), Api.I.get('dashboard', {'days': '1'})]);
      setState(() {
        me = Map<String, dynamic>.from(r[0]);
        dash = Map<String, dynamic>.from(r[1]);
      });
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final c = me == null ? const {} : Map<String, dynamic>.from(me!['counts'] ?? {});
    final cur = dash == null ? const {} : Map<String, dynamic>.from(dash!['current'] ?? dash!['cur'] ?? dash!['totals'] ?? {});
    Widget tile(String n, String t, String sub, bool hot, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: hot ? const Color(0xFFFFF4E0) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: hot ? const Color(0xFFF1D5A3) : line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: TextStyle(fontSize: 12, color: hot ? const Color(0xFF6B4A12) : muted)),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text('Hi ${Api.I.name.split(' ').first}'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () async {
          await Api.I.logout();
          toLogin();
        }),
      ]),
      body: RefreshIndicator(
        onRefresh: load,
        child: me == null
            ? ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator(color: wine))])
            : ListView(padding: const EdgeInsets.all(14), children: [
                const Text('Needs you today', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    tile('${c['new'] ?? 0}', 'New orders', 'Confirm, then pack', (c['new'] ?? 0) > 0, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'new')))),
                    tile('${c['returns'] ?? 0}', 'Return requests', 'Approve or arrange pickup', (c['returns'] ?? 0) > 0, () {}),
                    tile('${c['inbox'] ?? 0}', 'Messages need you', 'The AI handed these over', (c['inbox'] ?? 0) > 0, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen(filter: 'human')))),
                    tile('${c['abandoned'] ?? 0}', 'Abandoned checkouts', 'Remind on WhatsApp', false, () {}),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _stat('Sales today', rupees((cur['revenue'] as num?) ?? 0)),
                    _stat('Orders', '${cur['orders'] ?? 0}'),
                    _stat('COD', '${cur['cod'] ?? 0}'),
                  ]),
                ),
                const SizedBox(height: 12),
                const Text('Pull down to refresh. Full admin: peachpiper.com/admin', style: TextStyle(color: muted, fontSize: 12)),
              ]),
      ),
    );
  }

  Widget _stat(String k, String v) => Column(children: [Text(k, style: const TextStyle(color: muted, fontSize: 12)), Text(v, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))]);
}
