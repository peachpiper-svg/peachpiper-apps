import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';

/// Order tracking: order number + the mobile number (or email) used on the order → /api/track.php
class TrackScreen extends StatefulWidget {
  final String number;
  const TrackScreen({super.key, this.number = ''});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final numCtl = TextEditingController();
  final contact = TextEditingController();
  Map<String, dynamic>? r;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    numCtl.text = widget.number;
    final a = context.read<AccountState>();
    contact.text = (a.lastAddress['phone'] ?? a.customer?['email'] ?? '').toString();
    if (widget.number.isNotEmpty && contact.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final x = await Api.I.post('/api/track.php', {'order': numCtl.text.trim(), 'contact': contact.text.trim()});
      setState(() => r = Map<String, dynamic>.from(x));
    } catch (e) {
      setState(() => error = e.toString());
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track your order')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        TextField(controller: numCtl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Order number (starts with PP)')),
        const SizedBox(height: 10),
        TextField(controller: contact, decoration: const InputDecoration(labelText: 'Mobile number or email used on the order')),
        const SizedBox(height: 12),
        FilledButton(onPressed: busy ? null : _go, child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Track')),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFB3262E)))),
        if (r != null) ..._result(r!),
      ]),
    );
  }

  List<Widget> _result(Map<String, dynamic> r) {
    final steps = (r['steps'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e)).toList();
    final acts = (r['activities'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e)).toList();
    final items = (r['items'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e)).toList();
    return [
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: wine, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Order ${r['number']}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text((r['courier_status'] ?? '').toString().isNotEmpty ? r['courier_status'].toString() : (r['status_text'] ?? '').toString(),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          if ((r['etd'] ?? '').toString().isNotEmpty) Text('Expected ${r['etd']}', style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 6),
          Text('${r['payment']} · ${rupees((r['total'] as num?) ?? 0)}', style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 14),
      for (final s in steps)
        Row(children: [
          Icon(s['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: s['done'] == true ? const Color(0xFF1F7A4D) : muted, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text((s['label'] ?? '').toString(), style: TextStyle(fontWeight: s['done'] == true ? FontWeight.w700 : FontWeight.w500)))),
          if (s['at'] != null) Text(s['at'].toString().split(' ').first, style: const TextStyle(color: muted, fontSize: 12.5)),
        ]),
      if ((r['awb'] ?? '').toString().isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 10), child: Text('${r['courier']} · AWB ${r['awb']}', style: const TextStyle(fontWeight: FontWeight.w700))),
      if (acts.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text('Tracking history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final a in acts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 9, color: wine)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((a['activity'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${a['location'] ?? ''}  ·  ${a['date'] ?? ''}', style: const TextStyle(color: muted, fontSize: 12.5)),
              ])),
            ]),
          ),
      ],
      const SizedBox(height: 14),
      for (final i in items)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 44, height: 56, child: Photo((i['image'] ?? '').toString(), width: 160))),
          title: Text((i['title'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${i['variant'] ?? ''} × ${i['qty']}'),
        ),
      Text('Delivering to ${r['ship_to'] ?? ''}', style: const TextStyle(color: muted)),
      const SizedBox(height: 24),
    ];
  }
}
