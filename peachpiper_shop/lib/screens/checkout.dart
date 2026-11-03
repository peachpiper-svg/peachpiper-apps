import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../api.dart';
import '../main.dart';
import '../state.dart';
import 'success.dart';

/// Address + payment → /api/order.php (Cash on Delivery, or Razorpay for UPI / card) – the same order as on the website.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final f = <String, TextEditingController>{for (final k in ['name', 'phone', 'email', 'address1', 'address2', 'pincode', 'city', 'state']) k: TextEditingController()};
  Map<String, dynamic> errors = {};
  String method = 'cod';
  bool busy = false;
  String? error;
  late final Razorpay rzp;
  String pendingNumber = '';

  @override
  void initState() {
    super.initState();
    final acct = context.read<AccountState>();
    final a = acct.lastAddress;
    for (final k in f.keys) {
      f[k]!.text = (a[k] ?? '').toString();
    }
    final c = acct.customer;
    if (c != null) {
      if (f['email']!.text.isEmpty) f['email']!.text = (c['email'] ?? '').toString();
      final addrs = c['addresses'];
      if (f['address1']!.text.isEmpty && addrs is List && addrs.isNotEmpty) {
        final d = Map<String, dynamic>.from(addrs.firstWhere((x) => x['default'] == true, orElse: () => addrs.first));
        for (final k in ['name', 'phone', 'address1', 'address2', 'pincode', 'city', 'state']) {
          f[k]!.text = (d[k] ?? '').toString();
        }
      }
    }
    final s = context.read<StoreState>();
    if (!s.cod && s.online) method = 'online';
    rzp = Razorpay();
    rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, _paid);
    rzp.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) => setState(() {
          busy = false;
          error = 'Payment was not completed. You can try again, or choose Cash on Delivery.';
        }));
    rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    rzp.clear();
    super.dispose();
  }

  Future<void> _pin(String v) async {
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(v)) return;
    try {
      final r = await Api.I.get('/api/pinaddr.php?pin=$v');
      if (r['ok'] == true) {
        setState(() {
          if ((r['city'] ?? '').toString().isNotEmpty) f['city']!.text = r['city'].toString();
          if ((r['state'] ?? '').toString().isNotEmpty) f['state']!.text = r['state'].toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _place() async {
    final bag = context.read<BagState>();
    final acct = context.read<AccountState>();
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      errors = {};
    });
    final cust = {for (final e in f.entries) e.key: e.value.text.trim()};
    try {
      final r = await Api.I.post('/api/order.php', {
        'customer': cust,
        'items': bag.lines.map((l) => l.toOrderItem()).toList(),
        'coupon': bag.coupon,
        'method': method,
        'marketing': true,
        'source': {'utm_source': 'app', 'utm_medium': Platform.isIOS ? 'ios' : 'android', 'landing': 'app'},
      });
      await acct.rememberAddress(cust);
      if (r['razorpay'] is Map) {
        final z = Map<String, dynamic>.from(r['razorpay']);
        pendingNumber = r['number'].toString();
        rzp.open({
          'key': z['key'],
          'order_id': z['order_id'],
          'amount': z['amount'],
          'currency': z['currency'] ?? 'INR',
          'name': 'Peach Piper',
          'description': 'Order $pendingNumber',
          'prefill': z['prefill'] ?? {},
          'theme': {'color': '#5B1E2D'},
        });
        return;
      }
      _done(r['number'].toString());
    } on ApiError catch (e) {
      setState(() {
        busy = false;
        error = e.message;
        errors = e.fields ?? {};
      });
    } catch (e) {
      setState(() {
        busy = false;
        error = 'No connection. Check your internet and try again.';
      });
    }
  }

  Future<void> _paid(PaymentSuccessResponse p) async {
    try {
      final r = await Api.I.post('/api/verify.php', {
        'number': pendingNumber,
        'razorpay_order_id': p.orderId,
        'razorpay_payment_id': p.paymentId,
        'razorpay_signature': p.signature,
      });
      _done(r['number'].toString());
    } catch (e) {
      setState(() {
        busy = false;
        error = 'Payment received but we could not confirm it here. Do not pay again – we will confirm order $pendingNumber shortly.';
      });
    }
  }

  void _done(String number) {
    context.read<BagState>().clear();
    context.read<AccountState>().loadOrders();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => SuccessScreen(number)), (r) => r.isFirst);
  }

  Widget _field(String k, String label, {TextInputType? type, int? max, ValueChanged<String>? onChanged, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: f[k],
          keyboardType: type,
          maxLength: max,
          onChanged: onChanged,
          textCapitalization: type == null ? TextCapitalization.words : TextCapitalization.none,
          decoration: InputDecoration(labelText: label, hintText: hint, counterText: '', errorText: errors[k]?.toString()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bag = context.watch<BagState>();
    final s = context.watch<StoreState>();
    final total = bag.subtotal - bag.discount;
    final prepaid = method == 'online' ? s.prepaidOff : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('Delivery address', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _field('name', 'Full name'),
        _field('phone', 'Mobile number', type: TextInputType.phone, max: 10),
        _field('email', 'Email (optional – for order updates)', type: TextInputType.emailAddress),
        _field('pincode', 'Pincode', type: TextInputType.number, max: 6, onChanged: _pin),
        _field('address1', 'House no., building, street'),
        _field('address2', 'Area, landmark (optional)'),
        Row(children: [Expanded(child: _field('city', 'City')), const SizedBox(width: 10), Expanded(child: _field('state', 'State'))]),
        const SizedBox(height: 8),
        const Text('Payment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (s.online)
          _pay('online', 'Pay online – UPI, card, net banking', prepaid > 0 || s.prepaidOff > 0 ? 'Save ${rupees(s.prepaidOff)} extra' : 'Google Pay, PhonePe, Paytm and more'),
        if (s.cod) _pay('cod', 'Cash on Delivery', 'Pay when the parcel arrives'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
          child: Column(children: [
            _row('Items (${bag.count})', rupees(bag.subtotal)),
            if (bag.discount > 0) _row('Discount (${bag.coupon})', '− ${rupees(bag.discount)}'),
            if (prepaid > 0) _row('Online payment offer', '− ${rupees(prepaid)}'),
            _row('Shipping', 'Free'),
            const Divider(),
            _row('To pay', rupees(total - prepaid), bold: true),
          ]),
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFB3262E), fontWeight: FontWeight.w600))),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: busy || bag.lines.isEmpty ? null : _place,
          child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(method == 'cod' ? 'Place order · ${rupees(total)}' : 'Pay ${rupees(total - prepaid)}'),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _pay(String v, String t, String sub) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: method == v ? wine : line, width: method == v ? 1.6 : 1)),
        child: RadioListTile<String>(
          value: v,
          groupValue: method,
          activeColor: wine,
          onChanged: (x) => setState(() => method = x!),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub),
        ),
      );

  Widget _row(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16.5 : 14)),
        const Spacer(),
        Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16.5 : 14)),
      ]));
}
