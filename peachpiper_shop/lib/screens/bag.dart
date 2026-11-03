import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'checkout.dart';
import 'product.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({super.key});
  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  final code = TextEditingController();
  String? codeMsg;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final bag = context.watch<BagState>();
    final s = context.watch<StoreState>();
    if (bag.lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bag')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shopping_bag_outlined, size: 56, color: muted),
            const SizedBox(height: 10),
            const Text('Your bag is empty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => goTab(context, 1), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('Start shopping'))),
          ]),
        ),
      );
    }
    final total = bag.subtotal - bag.discount;
    final best = s.offers.where((o) => o.minQty <= bag.count && o.minTotal <= bag.subtotal && !o.first).toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: Text('Bag (${bag.count})')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        for (final l in bag.lines)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: () {
                  final p = s.byId(l.productId);
                  if (p != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p)));
                },
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 72, height: 90, child: Photo(l.image, width: 160))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (l.size.isNotEmpty) Text('Size ${l.size}', style: const TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(rupees(l.price * l.qty), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Row(children: [
                    IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline), onPressed: () => bag.setQty(l, l.qty - 1)),
                    Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline), onPressed: l.qty < 10 ? () => bag.setQty(l, l.qty + 1) : null),
                    const Spacer(),
                    TextButton(onPressed: () => bag.setQty(l, 0), child: const Text('Remove', style: TextStyle(color: muted))),
                  ]),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 6),
        if (best.isNotEmpty && bag.coupon.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.local_offer_outlined, color: wine),
              const SizedBox(width: 10),
              Expanded(child: Text('Use ${best.first.code} for ${best.first.label}', style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton(onPressed: busy ? null : () { code.text = best.first.code; _apply(bag); }, child: const Text('APPLY')),
            ]),
          ),
        Row(children: [
          Expanded(child: TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Discount code', isDense: true))),
          const SizedBox(width: 8),
          OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(90, 46)), onPressed: busy ? null : () => _apply(bag), child: const Text('Apply')),
        ]),
        if (codeMsg != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(codeMsg!, style: TextStyle(color: bag.coupon.isNotEmpty ? const Color(0xFF1F7A4D) : coral, fontWeight: FontWeight.w600))),
        const SizedBox(height: 16),
        _row('Subtotal', rupees(bag.subtotal)),
        if (bag.discount > 0) _row('Discount (${bag.coupon})', '− ${rupees(bag.discount)}', green: true),
        _row('Shipping', 'Free'),
        const Divider(height: 22),
        _row('Total', rupees(total), bold: true),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())), child: const Text('Checkout')),
        const SizedBox(height: 10),
        const Center(child: Text('Free shipping · Cash on Delivery · Easy 7-day exchange', style: TextStyle(color: muted, fontSize: 12.5))),
      ]),
    );
  }

  Future<void> _apply(BagState bag) async {
    if (code.text.trim().isEmpty) return;
    setState(() => busy = true);
    final err = await bag.applyCoupon(code.text.trim().toUpperCase(), context.read<AccountState>().lastAddress['phone']?.toString() ?? '');
    setState(() {
      busy = false;
      codeMsg = err ?? 'Code applied – you save ${rupees(bag.discount)}';
    });
  }

  Widget _row(String a, String b, {bool bold = false, bool green = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14.5)),
          const Spacer(),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 17 : 14.5, color: green ? const Color(0xFF1F7A4D) : ink)),
        ]),
      );
}
