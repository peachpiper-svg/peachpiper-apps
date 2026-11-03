import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../main.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/product_card.dart';

class ProductScreen extends StatefulWidget {
  final Product p;
  const ProductScreen(this.p, {super.key});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Variant? picked;
  int photo = 0;
  bool showSizeHint = false;

  @override
  void initState() {
    super.initState();
    final av = widget.p.variants.where((v) => v.available).toList();
    if (!widget.p.hasSizes && av.isNotEmpty) picked = av.first;
  }

  bool _needSize() {
    if (picked != null) return false;
    setState(() => showSizeHint = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose your size')));
    return true;
  }

  void _add({bool go = false}) {
    if (_needSize()) return;
    context.read<BagState>().add(widget.p, picked!);
    if (go) {
      goTab(context, 3);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added to bag – ${widget.p.title}${picked!.size.isNotEmpty && widget.p.hasSizes ? ' (${picked!.size})' : ''}'),
        action: SnackBarAction(label: 'VIEW BAG', textColor: coral, onPressed: () => goTab(context, 3)),
      ));
    }
  }

  Future<void> _whatsapp() async {
    final s = context.read<StoreState>();
    final digits = s.whatsapp.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final p = widget.p;
    final text = 'Hi! I want to order this:\n${p.title}${picked != null && p.hasSizes ? '\nSize: ${picked!.size}' : ''}\n$kSite/products/${p.slug}';
    await launchUrl(Uri.parse('https://wa.me/91${digits.substring(digits.length > 10 ? digits.length - 10 : 0)}?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final s = context.watch<StoreState>();
    final wish = context.watch<WishState>();
    final paired = s.pairFor(p);
    final similar = s.inCategory(p.category).where((x) => x.id != p.id && !paired.contains(x)).take(6).toList();
    final shown = picked ?? (p.variants.isNotEmpty ? p.variants.first : null);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(icon: Icon(wish.ids.contains(p.id) ? Icons.favorite : Icons.favorite_border, color: wish.ids.contains(p.id) ? coral : ink), onPressed: () => wish.toggle(p.id)),
          IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent('${p.title} – ${rupees(p.price)}\n$kSite/products/${p.slug}')}'), mode: LaunchMode.externalApplication)),
        ],
      ),
      body: ListView(children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(children: [
            PageView.builder(
              itemCount: p.images.isEmpty ? 1 : p.images.length,
              onPageChanged: (i) => setState(() => photo = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _Zoom(p.images, i))),
                child: Photo(p.images.isEmpty ? '' : p.images[i], width: 1080),
              ),
            ),
            if (p.images.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < p.images.length; i++)
                    Container(width: i == photo ? 18 : 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: i == photo ? wine : Colors.white, borderRadius: BorderRadius.circular(9))),
                ]),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 6),
            if (p.reviews > 0) Text('★ ${p.rating.toStringAsFixed(1)}  ·  ${p.reviews} review${p.reviews == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFFB7791F), fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
              Text(rupees(shown?.price ?? p.price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              if ((shown?.mrp ?? 0) > (shown?.price ?? 0)) Text(rupees(shown!.mrp), style: const TextStyle(fontSize: 16, color: muted, decoration: TextDecoration.lineThrough)),
              if ((shown?.mrp ?? 0) > (shown?.price ?? 0))
                Text('${((shown!.mrp - shown.price) * 100 / shown.mrp).round()}% off', style: const TextStyle(fontSize: 15, color: Color(0xFF1F7A4D), fontWeight: FontWeight.w800)),
            ]),
            const Text('Inclusive of all taxes · Free shipping', style: TextStyle(color: muted, fontSize: 12.5)),
            if (s.prepaidOff > 0 && s.online)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('Extra ${rupees(s.prepaidOff)} off when you pay online', style: const TextStyle(color: wine, fontWeight: FontWeight.w700, fontSize: 13))),
            if (p.hasSizes) ...[
              const SizedBox(height: 18),
              Text(picked == null ? 'Choose size' : 'Size: ${picked!.size}', style: TextStyle(fontWeight: FontWeight.w700, color: showSizeHint && picked == null ? coral : ink)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final v in p.variants)
                  ChoiceChip(
                    label: Text(v.size, style: TextStyle(decoration: v.available ? null : TextDecoration.lineThrough, fontWeight: FontWeight.w700)),
                    selected: picked?.id == v.id,
                    selectedColor: blush,
                    side: BorderSide(color: picked?.id == v.id ? wine : line),
                    onSelected: v.available ? (_) => setState(() => picked = v) : null,
                  ),
              ]),
            ],
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: p.available ? () => _add() : null, child: const Text('Add to bag'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: p.available ? () => _add(go: true) : null, child: Text(p.available ? 'Buy now' : 'Sold out'))),
            ]),
            const SizedBox(height: 10),
            if (s.whatsapp.isNotEmpty)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF128C4A), side: const BorderSide(color: Color(0xFF25D366), width: 1.4), minimumSize: const Size.fromHeight(48)),
                onPressed: _whatsapp,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Order on WhatsApp'),
              ),
            if (paired.isNotEmpty) ...[
              const SizedBox(height: 20),
              Center(child: Text(s.pairTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: wine))),
              const SizedBox(height: 12),
              SizedBox(
                height: 345,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: paired.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => PairTile(paired[i]),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _promise(Icons.local_shipping_outlined, 'Free shipping across India'),
            if (s.cod) _promise(Icons.payments_outlined, 'Cash on Delivery available'),
            _promise(Icons.swap_horiz, 'Easy 7-day exchange & return'),
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: true,
              title: const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(stripHtml(p.description), style: const TextStyle(height: 1.5, color: Color(0xFF3A3237))))],
            ),
          ]),
        ),
        if (similar.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('You may also like', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ProductGrid(similar, shrink: true),
        ],
      ]),
    );
  }

  Widget _promise(IconData i, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Icon(i, size: 20, color: wine), const SizedBox(width: 10), Text(t, style: const TextStyle(fontSize: 14))]));
}

class _Zoom extends StatelessWidget {
  final List<String> images;
  final int start;
  const _Zoom(this.images, this.start);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
        controller: PageController(initialPage: start),
        itemCount: images.length,
        itemBuilder: (_, i) => InteractiveViewer(maxScale: 4, child: Center(child: Photo(images[i], width: 1600, fit: BoxFit.contain))),
      ),
    );
  }
}

/// One piece in "Better together": photo, ADD, name, size picker and price – adds the chosen size without leaving the page.
class PairTile extends StatefulWidget {
  final Product p;
  const PairTile(this.p, {super.key});
  @override
  State<PairTile> createState() => _PairTileState();
}

class _PairTileState extends State<PairTile> {
  late final List<Variant> ok = widget.p.variants.where((v) => v.available).toList();
  late Variant? v = ok.isNotEmpty ? ok.first : null;
  bool added = false;

  void _add() {
    final cur = v;
    if (cur == null) return;
    context.read<BagState>().add(widget.p, cur);
    setState(() => added = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added to bag – ${widget.p.title}${ok.length > 1 ? ' (${cur.size})' : ''}'),
      action: SnackBarAction(label: 'VIEW BAG', textColor: coral, onPressed: () => goTab(context, 3)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p, cur = v;
    return SizedBox(
      width: 138,
      child: Column(children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p))),
          child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(10)), child: SizedBox(width: 138, height: 172, child: Photo(p.images.first, width: 320))),
        ),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton(
            onPressed: cur == null ? null : _add,
            style: FilledButton.styleFrom(backgroundColor: added ? const Color(0xFF1D7A46) : wine, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))), padding: EdgeInsets.zero),
            child: Text(added ? '✓ ADDED' : 'ADD', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 6),
        Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.25)),
        const SizedBox(height: 6),
        if (ok.length > 1)
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border.all(color: wine), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Variant>(
                value: cur,
                isDense: true,
                items: [for (final x in ok) DropdownMenuItem(value: x, child: Text(x.size, style: const TextStyle(fontSize: 14)))],
                onChanged: (x) => setState(() {
                  v = x;
                  added = false;
                }),
              ),
            ),
          ),
        const SizedBox(height: 6),
        if (cur != null)
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            if (cur.mrp > cur.price) Text(rupees(cur.mrp), style: const TextStyle(fontSize: 12, color: muted, decoration: TextDecoration.lineThrough)),
            Text(rupees(cur.price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFC0392B))),
          ]),
      ]),
    );
  }
}
