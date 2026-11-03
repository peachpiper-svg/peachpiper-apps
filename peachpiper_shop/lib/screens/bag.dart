import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../main.dart';
import '../models.dart';
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
        appBar: AppBar(title: const Text('Bag'), bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_bag_outlined, size: 42, color: coral),
              const SizedBox(height: 14),
              Text('Your bag is empty', style: serif(30)),
              const SizedBox(height: 8),
              Text('Pieces you add will wait here for you.', style: sans(14, color: muted)),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => goTab(context, 1), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('START SHOPPING'))),
            ]),
          ),
        ),
      );
    }
    final total = bag.subtotal - bag.discount;
    final best = s.offers.where((o) => o.minQty <= bag.count && o.minTotal <= bag.subtotal && !o.first).toList()..sort((a, b) => b.value.compareTo(a.value));
    /* the next "buy more, save more" code */
    final next = s.offers.where((o) => o.minQty > bag.count && o.type != 'percent').toList()..sort((a, b) => a.minQty.compareTo(b.minQty));
    /* one "complete the look" piece from the Better together picks */
    Product? sug;
    final inBag = bag.lines.map((l) => l.productId).toSet();
    for (final l in bag.lines) {
      final p = s.byId(l.productId);
      if (p == null) continue;
      final picks = s.pairFor(p);
      if (picks.any((x) => inBag.contains(x.id))) continue;
      if (picks.isNotEmpty) {
        sug = picks.first;
        break;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [Text('Bag', style: serif(24)), Text('${bag.count} PIECE${bag.count == 1 ? '' : 'S'}', style: kicker(color: muted, size: 9.5))]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        if (next.isNotEmpty && bag.coupon.isEmpty) _nextOffer(next.first, bag.count),
        for (final l in bag.lines) _line(context, bag, s, l),
        if (sug != null) _suggest(context, sug),
        const SizedBox(height: 10),
        if (best.isNotEmpty && bag.coupon.isEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFF6D3D0))),
            child: Row(children: [
              const Icon(Icons.local_offer_outlined, color: coralDark, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text.rich(TextSpan(children: [TextSpan(text: best.first.code, style: sans(13.5, weight: FontWeight.w800, color: wine)), TextSpan(text: '  ${best.first.label} on this bag', style: sans(13.5, color: ink))]))),
              TextButton(onPressed: busy ? null : () { code.text = best.first.code; _apply(bag); }, child: const Text('APPLY')),
            ]),
          ),
        Row(children: [
          Expanded(child: TextField(controller: code, textCapitalization: TextCapitalization.characters, style: sans(15, weight: FontWeight.w700, spacing: .6), decoration: const InputDecoration(hintText: 'Discount code', isDense: true))),
          const SizedBox(width: 8),
          OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(96, 48)), onPressed: busy ? null : () => _apply(bag), child: const Text('APPLY')),
        ]),
        if (codeMsg != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(codeMsg!, style: sans(13, weight: FontWeight.w600, color: bag.coupon.isNotEmpty ? emerald : coralDark))),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: line)),
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: Text('PRICE DETAILS', style: kicker(color: wine))),
            const SizedBox(height: 10),
            _row('Bag total', rupees(bag.subtotal)),
            if (bag.discount > 0) _row('Discount (${bag.coupon})', '− ${rupees(bag.discount)}', green: true),
            _row('Shipping', 'FREE', green: true),
            if (s.online && s.prepaidOff > 0) _row('Pay online and save', rupees(s.prepaidOff), note: true),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            _row('Total', rupees(total), bold: true),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline, size: 14, color: muted),
          const SizedBox(width: 6),
          Text('Safe checkout · Cash on Delivery · 7-day returns', style: sans(12, color: muted)),
        ]),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rupees(total), style: serif(26, height: 1)),
                Text('TOTAL', style: kicker(color: muted, size: 9.5)),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: coral, foregroundColor: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  child: const Text('PLACE ORDER'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _nextOffer(Offer o, int count) {
    final more = o.minQty - count;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: wine, borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Add $more more piece${more == 1 ? '' : 's'} ', style: sans(13.5, weight: FontWeight.w800, color: cream)),
          TextSpan(text: 'and get ${o.label} with ${o.code}', style: sans(13.5, color: const Color(0xFFF2D9D2))),
        ])),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: count / o.minQty, minHeight: 5, backgroundColor: const Color(0x33FFFFFF), color: coral),
        ),
      ]),
    );
  }

  Widget _line(BuildContext context, BagState bag, StoreState s, BagLine l) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () {
              final p = s.byId(l.productId);
              if (p != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p)));
            },
            child: ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 84, height: 112, child: Photo(l.image, width: 320))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(14, weight: FontWeight.w600, height: 1.3))),
                GestureDetector(onTap: () => bag.setQty(l, 0), child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.close, size: 18, color: muted))),
              ]),
              if (l.size.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('SIZE ${l.size}', style: kicker(color: muted, size: 10))),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  height: 34,
                  decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(4)),
                  child: Row(children: [
                    _qtyBtn(Icons.remove, () => bag.setQty(l, l.qty - 1)),
                    SizedBox(width: 26, child: Text('${l.qty}', textAlign: TextAlign.center, style: sans(14, weight: FontWeight.w800, color: wine))),
                    _qtyBtn(Icons.add, l.qty < 10 ? () => bag.setQty(l, l.qty + 1) : null),
                  ]),
                ),
                const Spacer(),
                Text(rupees(l.price * l.qty), style: sans(15, weight: FontWeight.w800, color: wine)),
              ]),
            ]),
          ),
        ]),
      );

  Widget _qtyBtn(IconData i, VoidCallback? onTap) => InkWell(onTap: onTap, child: SizedBox(width: 32, height: 34, child: Icon(i, size: 16, color: onTap == null ? line : wine)));

  Widget _suggest(BuildContext context, Product p) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFF6D3D0))),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 52, height: 66, child: Photo(p.images.first, width: 160))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('COMPLETE THE LOOK', style: kicker(size: 10)),
                const SizedBox(height: 3),
                Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14, weight: FontWeight.w700, color: wine)),
                Text(rupees(p.price), style: sans(13, color: ink)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: wine),
          ]),
        ),
      );

  Future<void> _apply(BagState bag) async {
    if (code.text.trim().isEmpty) return;
    setState(() => busy = true);
    final err = await bag.applyCoupon(code.text.trim().toUpperCase(), context.read<AccountState>().lastAddress['phone']?.toString() ?? '');
    if (!mounted) return;
    setState(() {
      busy = false;
      codeMsg = err ?? 'Code applied – you save ${rupees(bag.discount)}';
    });
  }

  Widget _row(String a, String b, {bool bold = false, bool green = false, bool note = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(a, style: bold ? serif(22) : sans(14, color: note ? muted : ink)),
          const Spacer(),
          Text(b, style: bold ? serif(24) : sans(14, weight: FontWeight.w700, color: green || note ? emerald : ink)),
        ]),
      );
}
