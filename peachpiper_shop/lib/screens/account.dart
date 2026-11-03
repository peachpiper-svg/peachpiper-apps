import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'track.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final email = TextEditingController();
  final code = TextEditingController();
  bool sent = false, busy = false;
  String? msg;

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AccountState>();
    final s = context.watch<StoreState>();
    final wish = context.watch<WishState>();
    final c = a.customer;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        if (c == null) _login(a) else ...[
          Text('Hi ${(c['name'] ?? '').toString().isNotEmpty ? c['name'] : c['email']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text((c['email'] ?? '').toString(), style: const TextStyle(color: muted)),
          const SizedBox(height: 14),
          const Text('My orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (a.orders.isEmpty) TextButton(onPressed: a.loadOrders, child: const Text('Load my orders')),
          for (final o in a.orders.take(20))
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: line)),
              child: ListTile(
                title: Text('${o['number']} · ${rupees((o['total'] as num?) ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${(o['status'] ?? '').toString().toUpperCase()} · ${(o['created_at'] ?? '').toString().split(' ').first}\n'
                    '${((o['items'] as List?) ?? const []).map((i) => '${i['title']} (${i['variant']})').join(', ')}', maxLines: 3, overflow: TextOverflow.ellipsis),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackScreen(number: o['number'].toString()))),
              ),
            ),
        ],
        const SizedBox(height: 10),
        _tile(Icons.local_shipping_outlined, 'Track an order', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackScreen()))),
        _tile(Icons.favorite_border, 'Wishlist (${wish.ids.length})', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()))),
        _tile(Icons.swap_horiz, 'Return or exchange', () => _open('$kSite/returns')),
        _tile(Icons.straighten, 'Size guide & help', () => _open('$kSite/help')),
        if (s.whatsapp.isNotEmpty) _tile(Icons.chat_outlined, 'WhatsApp us', () => _open('https://wa.me/91${s.whatsapp}?text=${Uri.encodeComponent('Hi Peach Piper! I need help')}')),
        if ((s.contact['phone'] ?? '').toString().isNotEmpty) _tile(Icons.call_outlined, 'Call us', () => _open('tel:+91${s.contact['phone']}')),
        if ((s.contact['email'] ?? '').toString().isNotEmpty) _tile(Icons.mail_outline, 'Email us', () => _open('mailto:${s.contact['email']}')),
        const Divider(height: 28),
        _tile(Icons.privacy_tip_outlined, 'Privacy policy', () => _open('$kSite/policies/privacy.html')),
        _tile(Icons.description_outlined, 'Terms of service', () => _open('$kSite/policies/terms.html')),
        _tile(Icons.assignment_return_outlined, 'Refund policy', () => _open('$kSite/policies/refund.html')),
        _tile(Icons.local_shipping_outlined, 'Shipping policy', () => _open('$kSite/policies/shipping.html')),
        if (c != null) ...[
          _tile(Icons.logout, 'Log out', a.logout),
          _tile(Icons.delete_outline, 'Delete my account', () async {
            final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                      title: const Text('Delete your account?'),
                      content: const Text('Your login, saved addresses and wishlist are removed. Orders you already placed stay with the shop for delivery, returns and tax records.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFB3262E))))],
                    ));
            if (ok == true) {
              try {
                await a.deleteAccount();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account was deleted')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          }),
        ],
        const SizedBox(height: 16),
        Center(child: Text('${s.contact['legal_name'] ?? 'Peach Piper'} · ${s.contact['address'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 11.5))),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _login(AccountState a) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Log in to see your orders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('We email you a 6-digit code – no password needed.', style: TextStyle(color: muted)),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, enabled: !sent, decoration: const InputDecoration(labelText: 'Email')),
          if (sent) ...[
            const SizedBox(height: 10),
            TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit code', counterText: '')),
          ],
          if (msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg!, style: const TextStyle(color: Color(0xFFB3262E)))),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      msg = null;
                    });
                    try {
                      if (!sent) {
                        await a.sendCode(email.text.trim());
                        sent = true;
                      } else {
                        await a.verify(email.text.trim(), code.text.trim());
                      }
                    } catch (e) {
                      msg = e.toString();
                    }
                    setState(() => busy = false);
                  },
            child: Text(sent ? 'Log in' : 'Send code'),
          ),
          if (sent) TextButton(onPressed: () => setState(() => sent = false), child: const Text('Use another email')),
        ]),
      );

  Widget _tile(IconData i, String t, VoidCallback onTap) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(i, color: wine), title: Text(t), trailing: const Icon(Icons.chevron_right, color: muted), onTap: onTap);

  Future<void> _open(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
}

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final wish = context.watch<WishState>();
    final items = s.products.where((p) => wish.ids.contains(p.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: items.isEmpty ? const Center(child: Text('Tap ♡ on a style to save it here.', style: TextStyle(color: muted))) : ProductGrid(items),
    );
  }
}
