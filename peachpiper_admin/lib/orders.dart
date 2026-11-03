import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'main.dart';

const statusText = {
  'new': 'New', 'confirmed': 'Confirmed', 'packed': 'Packed', 'shipped': 'Shipped', 'delivered': 'Delivered', 'cancelled': 'Cancelled', 'returned': 'Returned', 'awaiting_payment': 'Awaiting payment',
};
const nextStep = {'new': 'confirmed', 'confirmed': 'packed', 'packed': 'shipped', 'shipped': 'delivered'};

class OrdersScreen extends StatefulWidget {
  final String status;
  const OrdersScreen({super.key, this.status = 'open'});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late String status = widget.status;
  final q = TextEditingController();
  List<Map<String, dynamic>> orders = [];
  bool busy = true;

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final r = await Api.I.get('orders.list', {'status': status == 'all' ? '' : status, if (q.text.trim().isNotEmpty) 'q': q.text.trim()});
      orders = ((r['orders'] as List?) ?? const []).map((o) => Map<String, dynamic>.from(o)).toList();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [['open', 'To do'], ['new', 'New'], ['confirmed', 'Confirmed'], ['packed', 'Packed'], ['shipped', 'Shipped'], ['delivered', 'Delivered'], ['all', 'All']];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: q,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => load(),
          decoration: const InputDecoration(hintText: 'Search order, name, phone', prefixIcon: Icon(Icons.search), isDense: true),
        ),
      ),
      body: Column(children: [
        SizedBox(
          height: 50,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), children: [
            for (final t in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(t[1]), selected: status == t[0], onSelected: (_) {
                  status = t[0];
                  load();
                }),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: busy && orders.isEmpty
                ? ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator(color: wine))])
                : orders.isEmpty
                    ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No orders here', style: TextStyle(color: muted)))])
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final o = orders[i];
                          return ListTile(
                            tileColor: Colors.white,
                            title: Text('${o['number']} · ${o['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${when((o['created_at'] ?? '').toString())} · ${o['city'] ?? ''}\n${((o['items'] as List?) ?? const []).map((x) => '${x['title']} (${x['variant']})').join(', ')}',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(rupees((o['total'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              _pill(o['status'].toString(), (o['payment_method'] ?? '').toString()),
                            ]),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(o['id'] as int)));
                              load();
                            },
                          );
                        },
                      ),
          ),
        ),
      ]),
    );
  }
}

Widget _pill(String st, String pay) {
  final colors = {'new': const Color(0xFFFFF4E0), 'confirmed': const Color(0xFFEAF0FB), 'packed': const Color(0xFFEAF0FB), 'shipped': const Color(0xFFE3F4EA), 'delivered': const Color(0xFFE3F4EA)};
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: colors[st] ?? const Color(0xFFF0EEF1), borderRadius: BorderRadius.circular(999)),
    child: Text('${statusText[st] ?? st}${pay == 'cod' ? ' · COD' : ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
  );
}

class OrderScreen extends StatefulWidget {
  final int id;
  const OrderScreen(this.id, {super.key});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Map<String, dynamic>? o;
  List log = [];
  bool busy = false;

  Future<void> load() async {
    try {
      final r = await Api.I.get('orders.get', {'id': '${widget.id}'});
      setState(() {
        o = Map<String, dynamic>.from(r['order']);
        log = (r['log'] as List?) ?? [];
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

  Future<void> _status(String to) async {
    setState(() => busy = true);
    try {
      await Api.I.post('orders.update', {'id': widget.id, 'status': to, 'note': o?['note'] ?? ''});
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked ${statusText[to]}')));
    } catch (e) {
      if (mounted) showErr(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _whatsapp() async {
    final x = o!;
    final first = (x['name'] ?? '').toString().split(' ').first;
    final items = ((x['items'] as List?) ?? const []).map((i) => '🛍️ ${i['title']} – Size ${i['variant']}').join('\n');
    final ctl = TextEditingController(
        text: 'Namaste $first 🙏\n\nThank you for shopping with *Peach Piper* 💖\n\n🧾 *Order ${x['number']}*\n$items\n💰 Total: *${rupees((x['total'] as num?) ?? 0)}*${x['payment_method'] == 'cod' ? ' · Cash on Delivery' : ''}\n\n📦 Track: ${x['track'] ?? ''}');
    final send = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('WhatsApp +91 ${x['phone']}'),
        content: TextField(controller: ctl, maxLines: 10, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Send'))],
      ),
    );
    if (send != true) return;
    final img = ((x['items'] as List?) ?? const []).map((i) => (i['image'] ?? '').toString()).where((u) => u.isNotEmpty).map((u) => u.startsWith('/') ? '$kSite$u' : u).take(1).toList();
    try {
      final r = await Api.I.post('orders.wa_send', {'phone': x['phone'], 'text': ctl.text, 'images': img});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent on WhatsApp${(r['photos'] ?? 0) > 0 ? ' with photo' : ''}')));
    } catch (e) {
      // outside the 24-hour window (or API off): open WhatsApp with the message
      await launchUrl(Uri.parse('https://wa.me/91${x['phone']}?text=${Uri.encodeComponent(ctl.text)}'), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _addrCheck() async {
    try {
      final r = await Api.I.post('orders.addr_check', {'number': o!['number']});
      if (r['ok'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address check sent on WhatsApp')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((r['msg'] ?? '').toString())));
        await launchUrl(Uri.parse('https://wa.me/91${o!['phone']}?text=${Uri.encodeComponent((r['text'] ?? '').toString())}'), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = o;
    if (x == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator(color: wine)));
    final st = x['status'].toString();
    final next = nextStep[st];
    final items = (x['items'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('${x['number']}')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(14), children: [
          Row(children: [_pill(st, (x['payment_method'] ?? '').toString()), const SizedBox(width: 8), Text(when((x['created_at'] ?? '').toString()), style: const TextStyle(color: muted))]),
          if ((x['risk'] ?? '').toString().isNotEmpty)
            Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(10)),
                child: Text('⚠ ${x['risk']}', style: const TextStyle(color: Color(0xFF6B4A12)))),
          const SizedBox(height: 12),
          _card([
            for (final i in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(width: 44, height: 56, child: (i['image'] ?? '').toString().isEmpty ? Container(color: line) : CachedNetworkImage(imageUrl: imgUrl(i['image'].toString()), fit: BoxFit.cover))),
                title: Text((i['title'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${i['variant'] ?? ''} · ${rupees((i['price'] as num?) ?? 0)} × ${i['qty']}'),
              ),
            const Divider(),
            Row(children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(rupees((x['total'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ]),
            Text(x['payment_method'] == 'cod' ? 'Cash on Delivery' : 'Online · ${x['payment_status']}', style: const TextStyle(color: muted)),
          ]),
          _card([
            Text((x['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('+91 ${x['phone']}'),
            const SizedBox(height: 6),
            Text('${x['address1'] ?? ''}${(x['address2'] ?? '').toString().isNotEmpty ? ', ${x['address2']}' : ''}\n${x['city']}, ${x['state']} ${x['pincode']}', style: const TextStyle(height: 1.4)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _whatsapp, icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('WhatsApp')),
              if (['new', 'confirmed', 'packed'].contains(st)) OutlinedButton.icon(onPressed: _addrCheck, icon: const Icon(Icons.place_outlined, size: 18), label: const Text('Check address')),
              OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:+91${x['phone']}')), icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Call')),
              if ((x['track'] ?? '').toString().isNotEmpty)
                OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(x['track'].toString()), mode: LaunchMode.externalApplication), icon: const Icon(Icons.local_shipping_outlined, size: 18), label: const Text('Tracking')),
            ]),
          ]),
          if ((x['awb'] ?? '').toString().isNotEmpty) _card([Text('${x['courier'] ?? ''} · AWB ${x['awb']}', style: const TextStyle(fontWeight: FontWeight.w700)), if ((x['ship_status'] ?? '').toString().isNotEmpty) Text(x['ship_status'].toString())]),
          const SizedBox(height: 4),
          if (next != null) FilledButton(onPressed: busy ? null : () => _status(next), child: Text('Mark ${statusText[next]}')),
          const SizedBox(height: 8),
          if (['new', 'confirmed', 'packed'].contains(st))
            TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(title: const Text('Cancel this order?'), actions: [
                                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')),
                                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Cancel order', style: TextStyle(color: Color(0xFFB3262E)))),
                                ]));
                        if (ok == true) _status('cancelled');
                      },
                child: const Text('Cancel order', style: TextStyle(color: Color(0xFFB3262E)))),
          const SizedBox(height: 10),
          const Text('Activity', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final l in log.take(15)) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${when((l['at'] ?? '').toString())} · ${l['detail']}', style: const TextStyle(fontSize: 13, color: muted))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _card(List<Widget> c) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: c));
}
