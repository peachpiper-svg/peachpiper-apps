import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'track.dart';
import 'wishlist.dart';

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
      appBar: AppBar(title: const Text('Account'), bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider())),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        if (c == null) _login(a) else ...[
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(color: wine, borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NAMASTE', style: kicker(color: goldSoft)),
              const SizedBox(height: 4),
              Text('${(c['name'] ?? '').toString().isNotEmpty ? c['name'] : 'Welcome back'}', style: serif(30, color: const Color(0xFFFFF4EC))),
              const SizedBox(height: 2),
              Text((c['email'] ?? '').toString(), style: sans(13, color: const Color(0xFFF2D9D2))),
            ]),
          ),
          const SizedBox(height: 22),
          Text('My orders', style: serif(24)),
          const SizedBox(height: 6),
          if (a.orders.isEmpty) TextButton(onPressed: a.loadOrders, child: const Text('Load my orders')),
          for (final o in a.orders.take(20))
            Card(
              elevation: 0,
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: line)),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('WELCOME', style: kicker()),
          const SizedBox(height: 4),
          Text('Log in to your account', style: serif(28)),
          const SizedBox(height: 6),
          Text('See your orders, track parcels and check out faster. We email you a 6-digit code – no password needed.', style: sans(13.5, color: muted, height: 1.5)),
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
            child: Text(sent ? 'LOG IN' : 'SEND CODE'),
          ),
          if (sent) TextButton(onPressed: () => setState(() => sent = false), child: const Text('Use another email')),
        ]),
      );

  Widget _tile(IconData i, String t, VoidCallback onTap) => Column(children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: goldSoft)), child: Icon(i, color: wine, size: 19)),
          title: Text(t, style: sans(15, weight: FontWeight.w600, color: ink)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: onTap,
        ),
        const Divider(),
      ]);

  Future<void> _open(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
}
