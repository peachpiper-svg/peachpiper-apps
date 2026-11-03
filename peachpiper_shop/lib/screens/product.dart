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
        if (paired.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(s.pairTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          SizedBox(
            height: 330,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: paired.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => PairTile(paired[i]),
            ),
          ),
        ],
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

/// One piece in "Customers also buy with this": tap the photo to open it, "+ Add" puts it in the bag (asks the size first when there are several).
class PairTile extends StatefulWidget {
  final Product p;
  const PairTile(this.p, {super.key});
  @override
  State<PairTile> createState() => _PairTileState();
}

class _PairTileState extends State<PairTile> {
  String? added;

  void _put(Variant v) {
    context.read<BagState>().add(widget.p, v);
    setState(() => added = widget.p.hasSizes ? v.size : '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added to bag – ${widget.p.title}'),
      action: SnackBarAction(label: 'VIEW BAG', textColor: coral, onPressed: () => goTab(context, 3)),
    ));
  }

  void _add() {
    final ok = widget.p.variants.where((v) => v.available).toList();
    if (ok.isEmpty) return;
    if (ok.length == 1) return _put(ok.first);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Choose size', style: TextStyle(color: muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final v in ok)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheet);
                    _put(v);
                  },
                  child: Text(v.size),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return SizedBox(
      width: 150,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 150, height: 190, child: Photo(p.images.first, width: 320))),
            const SizedBox(height: 6),
            Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.25)),
            const SizedBox(height: 2),
            PriceRow(p, size: 14),
          ]),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: added != null
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('✓ Added${added!.isNotEmpty ? ' – $added' : ''}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1D7A46), fontWeight: FontWeight.w700)))
              : OutlinedButton(onPressed: p.available ? _add : null, child: const Text('+ Add')),
        ),
      ]),
    );
  }
}
