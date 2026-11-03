import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../main.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/product_card.dart';

/// Product page: full-bleed photos, price and offers, sizes with the size chart, delivery check,
/// Better together, details, reviews, similar and recently viewed; Add to bag / Buy now stay at the bottom.
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
  Map<String, dynamic>? reviews;
  final pin = TextEditingController();
  String? pinMsg;
  bool pinOk = true, pinBusy = false;

  @override
  void initState() {
    super.initState();
    final av = widget.p.variants.where((v) => v.available).toList();
    if (!widget.p.hasSizes && av.isNotEmpty) picked = av.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RecentState>().saw(widget.p.id);
    });
    _loadReviews();
    final last = context.read<AccountState>().lastAddress['pincode']?.toString() ?? '';
    if (last.length == 6) {
      pin.text = last;
      _checkPin();
    }
  }

  Future<void> _loadReviews() async {
    try {
      final r = await Api.I.get('/api/reviews.php?a=list&pid=${Uri.encodeComponent(widget.p.id)}');
      if (mounted) setState(() => reviews = Map<String, dynamic>.from(r));
    } catch (_) {}
  }

  Future<void> _checkPin() async {
    final p = pin.text.trim();
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(p)) {
      setState(() {
        pinOk = false;
        pinMsg = 'Enter a valid 6-digit pincode';
      });
      return;
    }
    setState(() => pinBusy = true);
    try {
      final r = await Api.I.get('/api/pincode.php?pin=$p');
      final ok = r['ok'] == true;
      final min = (r['min'] as num?)?.toInt() ?? 4, max = (r['max'] as num?)?.toInt() ?? 7;
      final city = (r['city'] ?? '').toString();
      setState(() {
        pinOk = ok;
        pinMsg = ok
            ? 'Delivery by ${_date(min)} – ${_date(max)}${city.isNotEmpty ? ' to $city' : ''}${r['cod'] == true ? ' · Cash on Delivery available' : ' · Pay online for this pincode'}'
            : 'Sorry, we do not deliver to $p yet.';
      });
    } catch (e) {
      setState(() {
        pinOk = false;
        pinMsg = e.toString();
      });
    }
    if (mounted) setState(() => pinBusy = false);
  }

  String _date(int days) {
    var d = DateTime.now();
    var n = 0;
    while (n < days) {
      d = d.add(const Duration(days: 1));
      if (d.weekday != DateTime.sunday) n++;
    }
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  /// no size chosen yet: ask for it in a sheet, then continue
  Future<bool> _needSize() async {
    if (picked != null) return false;
    final v = await showModalBottomSheet<Variant>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Select size', style: serif(26)),
              const Spacer(),
              TextButton(onPressed: () => _chart(ctx), child: const Text('SIZE CHART')),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final v in widget.p.variants) _sizeBox(v, false, v.available ? () => Navigator.pop(ctx, v) : null),
            ]),
          ]),
        ),
      ),
    );
    if (v == null) return true;
    setState(() => picked = v);
    return false;
  }

  Future<void> _add({bool go = false}) async {
    if (await _needSize()) return;
    if (!mounted) return;
    context.read<BagState>().add(widget.p, picked!);
    if (go) {
      goTab(context, 3);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added to bag${widget.p.hasSizes ? ' – size ${picked!.size}' : ''}'),
        action: SnackBarAction(label: 'VIEW BAG', onPressed: () => goTab(context, 3)),
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

  void _share() => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent('${widget.p.title} – ${rupees(widget.p.price)}\n$kSite/products/${widget.p.slug}')}'),
      mode: LaunchMode.externalApplication);

  /// the size chart from Admin → Pages & policies
  void _chart(BuildContext ctx) {
    final pr = context.read<StoreState>().pdpSettings;
    final head = (pr['chart_head'] is List ? pr['chart_head'] as List : const ['Size', 'Bust', 'Waist', 'Hip', 'Kurta length']).map((e) => e.toString()).toList();
    final rows = (pr['chart_rows'] is List ? pr['chart_rows'] as List : const []).whereType<List>().map((r) => r.map((e) => e.toString()).toList()).toList();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Size chart', style: serif(28)),
            const SizedBox(height: 4),
            Text((pr['chart_note'] ?? 'Measurements in inches.').toString(), style: sans(13, color: muted)),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: const TableBorder(horizontalInside: BorderSide(color: line)),
                children: [
                  TableRow(decoration: const BoxDecoration(color: wine), children: [
                    for (final h in head) Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Text(h.toUpperCase(), style: kicker(color: cream, size: 10.5))),
                  ]),
                  for (var i = 0; i < rows.length; i++)
                    TableRow(decoration: BoxDecoration(color: i.isEven ? Colors.white : blush), children: [
                      for (var j = 0; j < head.length; j++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Text(j < rows[i].length ? rows[i][j] : '', style: sans(14, weight: j == 0 ? FontWeight.w800 : FontWeight.w500, color: j == 0 ? wine : ink)),
                        ),
                    ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sizeBox(Variant v, bool on, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 54),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? wine : (v.available ? Colors.white : const Color(0xFFF7F2F1)),
            border: Border.all(color: on ? wine : (v.available ? const Color(0xFFD9C6C1) : line)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(v.size,
              style: sans(14, weight: FontWeight.w700, color: on ? cream : (v.available ? wine : muted)).copyWith(decoration: v.available ? null : TextDecoration.lineThrough)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final s = context.watch<StoreState>();
    final wish = context.watch<WishState>();
    final recent = context.watch<RecentState>();
    final paired = s.pairFor(p);
    final similar = s.inCategory(p.category).where((x) => x.id != p.id && !paired.contains(x)).take(10).toList();
    final viewed = recent.viewed.where((id) => id != p.id).map(s.byId).whereType<Product>().where((x) => x.available).take(10).toList();
    final shown = picked ?? (p.variants.isNotEmpty ? p.variants.first : null);
    final now = shown?.price ?? p.price, was = shown?.mrp ?? p.mrp;
    final w = MediaQuery.of(context).size.width;
    final onWish = wish.ids.contains(p.id);
    final pr = s.pdpSettings;
    final dmin = (pr['delivery_min'] as num?)?.toInt() ?? 4, dmax = (pr['delivery_max'] as num?)?.toInt() ?? 6;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(padding: const EdgeInsets.all(6), child: _circle(Icons.arrow_back, () => Navigator.pop(context))),
        actions: [
          _circle(Icons.ios_share, _share),
          const SizedBox(width: 6),
          _circle(onWish ? Icons.favorite : Icons.favorite_border, () => wish.toggle(p.id), color: onWish ? coral : wine),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        /* photos */
        SizedBox(
          height: w * 4 / 3,
          child: Stack(children: [
            PageView.builder(
              itemCount: p.images.isEmpty ? 1 : p.images.length,
              onPageChanged: (i) => setState(() => photo = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _Zoom(p.images, i))),
                child: Photo(p.images.isEmpty ? '' : p.images[i], width: 1080, alignment: const Alignment(0, -.3)),
              ),
            ),
            if (p.images.length > 1)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < p.images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == photo ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: i == photo ? wine : Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(6)),
                    ),
                ]),
              ),
          ]),
        ),
        /* name, price */
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.categoryName(p.category).toUpperCase(), style: kicker()),
            const SizedBox(height: 6),
            Text(p.title, style: serif(28, height: 1.08)),
            if (p.reviews > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: emerald, borderRadius: BorderRadius.circular(3)),
                    child: Text('${p.rating.toStringAsFixed(1)} ★', style: sans(12, weight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  Text('${p.reviews} review${p.reviews == 1 ? '' : 's'}', style: sans(13, color: muted)),
                ]),
              ),
            const SizedBox(height: 12),
            PriceRow(now, was, size: 22),
            const SizedBox(height: 2),
            Text('Inclusive of all taxes · Free shipping', style: sans(12, color: muted)),
          ]),
        ),
        _offers(s, now),
        /* sizes */
        if (p.hasSizes)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('SELECT SIZE', style: kicker(color: wine)),
                if (picked != null) Text('  ·  ${picked!.size}', style: sans(12, weight: FontWeight.w700, color: coralDark)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _chart(context),
                  child: Row(children: [
                    const Icon(Icons.straighten, size: 16, color: coralDark),
                    const SizedBox(width: 4),
                    Text('SIZE CHART', style: kicker(color: coralDark, size: 10.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final v in p.variants) _sizeBox(v, picked?.id == v.id, v.available ? () => setState(() => picked = v) : null),
              ]),
              if (p.variants.where((v) => v.available).length <= 2 && p.available)
                Padding(padding: const EdgeInsets.only(top: 10), child: Text('Only a few sizes left', style: sans(12.5, weight: FontWeight.w700, color: coralDark))),
            ]),
          ),
        /* WhatsApp order */
        if (s.whatsapp.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF128C4A), side: const BorderSide(color: Color(0xFF25D366)), minimumSize: const Size.fromHeight(48)),
              onPressed: _whatsapp,
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('ORDER ON WHATSAPP'),
            ),
          ),
        /* Better together */
        if (paired.isNotEmpty) ...[
          const SectionTitle('Better together', padding: EdgeInsets.fromLTRB(18, 30, 18, 14)),
          SizedBox(
            height: 350,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: paired.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => PairTile(paired[i]),
            ),
          ),
        ],
        /* delivery */
        Container(
          margin: const EdgeInsets.fromLTRB(18, 26, 18, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFF6D9D6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.local_shipping_outlined, color: wine, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Delivered by ${_date(dmin)} – ${_date(dmax)}', style: sans(14, weight: FontWeight.w700, color: wine))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: pin,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: sans(15, weight: FontWeight.w600),
                  decoration: const InputDecoration(hintText: 'Enter pincode', counterText: '', isDense: true),
                  onSubmitted: (_) => _checkPin(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(88, 46)),
                  onPressed: pinBusy ? null : _checkPin,
                  child: pinBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cream)) : const Text('CHECK'),
                ),
              ),
            ]),
            if (pinMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(pinMsg!, style: sans(13, weight: FontWeight.w600, color: pinOk ? emerald : coralDark))),
          ]),
        ),
        /* promises */
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Row(children: [
            _promise(Icons.local_shipping_outlined, 'Free\nshipping'),
            if (s.cod) _promise(Icons.payments_outlined, 'Cash on\ndelivery'),
            _promise(Icons.autorenew, '7-day easy\nreturns'),
            _promise(Icons.verified_outlined, 'Quality\nchecked'),
          ]),
        ),
        /* details */
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(children: [
            const Divider(),
            ExpansionTile(
              initiallyExpanded: true,
              title: Text('Product details', style: serif(22)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(stripHtml(p.description).isEmpty ? 'Details coming soon.' : stripHtml(p.description), style: sans(14, color: wineSoft, height: 1.6)))],
            ),
            const Divider(),
            ExpansionTile(
              title: Text('Returns & exchange', style: serif(22)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(stripHtml((pr['returns'] ?? '').toString()).isEmpty ? 'Easy 7-day returns and exchange.' : stripHtml(pr['returns'].toString()), style: sans(14, color: wineSoft, height: 1.6)))],
            ),
            const Divider(),
            ExpansionTile(
              title: Text('Manufacturing information', style: serif(22)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Manufactured & marketed by ${pr['manufacturer'] ?? 'Shiksha Enterprise'}\n${pr['address'] ?? ''}\nCountry of origin: ${pr['origin'] ?? 'India'}',
                      style: sans(14, color: wineSoft, height: 1.6)),
                ),
              ],
            ),
            const Divider(),
          ]),
        ),
        _reviews(),
        if (similar.isNotEmpty) ...[
          const SectionTitle('You may also like'),
          ProductRail(similar),
        ],
        if (viewed.isNotEmpty) ...[
          const SectionTitle('Recently viewed'),
          ProductRail(viewed),
        ],
        const SizedBox(height: 30),
      ]),
      /* sticky buy bar */
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              SizedBox(
                width: 52,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(52, 52)),
                  onPressed: () => wish.toggle(p.id),
                  child: Icon(onWish ? Icons.favorite : Icons.favorite_border, color: onWish ? coral : wine),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: p.available ? () => _add() : null, child: const Text('ADD TO BAG'))),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: coral, foregroundColor: Colors.white),
                  onPressed: p.available ? () => _add(go: true) : null,
                  child: Text(p.available ? 'BUY NOW' : 'SOLD OUT'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _circle(IconData i, VoidCallback onTap, {Color color = wine}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8)]),
          child: Icon(i, color: color, size: 20),
        ),
      );

  Widget _promise(IconData i, String t) => Expanded(
        child: Column(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: goldSoft)),
            child: Icon(i, size: 20, color: wine),
          ),
          const SizedBox(height: 6),
          Text(t, textAlign: TextAlign.center, style: sans(11, weight: FontWeight.w600, color: wineSoft, height: 1.25)),
        ]),
      );

  /// codes from Admin → Discounts, and the pay-online saving
  Widget _offers(StoreState s, int price) {
    final codes = s.offers.where((o) => o.minQty <= 1 && (o.minTotal == 0 || price >= o.minTotal)).toList();
    final more = s.offers.where((o) => o.minQty > 1).toList();
    final list = [...codes, ...more].take(3).toList();
    final pre = s.online && s.prepaidOff > 0;
    if (list.isEmpty && !pre) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.local_offer_outlined, color: coralDark, size: 18), const SizedBox(width: 6), Text('OFFERS FOR YOU', style: kicker(color: wine))]),
        const SizedBox(height: 8),
        for (final o in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: blush, border: Border.all(color: coral), borderRadius: BorderRadius.circular(3)),
                child: Text(o.code, style: sans(12, weight: FontWeight.w800, color: coralDark, spacing: .6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${o.label}${o.minQty > 1 ? ' on ${o.minQty} pieces' : ''}${o.minTotal > 0 ? ' above ${rupees(o.minTotal)}' : ''}${o.first ? ' · first order' : ''}',
                    style: sans(13, color: ink)),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: o.code));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${o.code} copied – apply it in your bag')));
                },
                child: Padding(padding: const EdgeInsets.all(4), child: Text('COPY', style: kicker(color: wine, size: 10))),
              ),
            ]),
          ),
        if (pre)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE6F3EC), border: Border.all(color: emerald), borderRadius: BorderRadius.circular(3)),
                child: Text('UPI', style: sans(12, weight: FontWeight.w800, color: emerald)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Extra ${rupees(s.prepaidOff)} off when you pay online', style: sans(13, color: ink))),
            ]),
          ),
      ]),
    );
  }

  /// ratings and the latest reviews (from /api/reviews.php)
  Widget _reviews() {
    final r = reviews;
    if (r == null) return const SizedBox.shrink();
    final sum = r['summary'] is Map ? Map<String, dynamic>.from(r['summary']) : <String, dynamic>{};
    final n = (sum['count'] as num?)?.toInt() ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final avg = (sum['avg'] as num?)?.toDouble() ?? 0;
    final dist = sum['dist'] is Map ? Map<String, dynamic>.from(sum['dist']) : <String, dynamic>{};
    final list = (r['reviews'] is List ? r['reviews'] as List : const []).whereType<Map>().take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Customer reviews', padding: EdgeInsets.fromLTRB(0, 26, 0, 16)),
        Row(children: [
          Column(children: [
            Text(avg.toStringAsFixed(1), style: serif(52, height: 1)),
            Text('★★★★★'.substring(0, avg.round().clamp(1, 5).toInt()), style: const TextStyle(color: gold, fontSize: 16)),
            Text('$n reviews', style: sans(12, color: muted)),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child: Column(children: [
              for (var st = 5; st >= 1; st--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 16, child: Text('$st', style: sans(12, weight: FontWeight.w700, color: wine))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: n == 0 ? 0 : ((dist['$st'] as num?)?.toDouble() ?? 0) / n,
                          minHeight: 6,
                          backgroundColor: line,
                          color: st >= 4 ? emerald : (st == 3 ? gold : coral),
                        ),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        for (final rv in list)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${rv['rating']} ★', style: sans(13, weight: FontWeight.w800, color: emerald)),
                const SizedBox(width: 8),
                Expanded(child: Text((rv['title'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14, weight: FontWeight.w700))),
              ]),
              if ((rv['body'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(rv['body'].toString(), style: sans(13.5, color: wineSoft, height: 1.5))),
              if (rv['photos'] is List && (rv['photos'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 64,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final ph in (rv['photos'] as List).take(4))
                        Padding(padding: const EdgeInsets.only(right: 6), child: ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 52, height: 64, child: Photo(ph.toString(), width: 160)))),
                    ]),
                  ),
                ),
              const SizedBox(height: 6),
              Text('${rv['name'] ?? ''}${(rv['city'] ?? '').toString().isNotEmpty ? ', ${rv['city']}' : ''}${rv['verified'] == true ? '  ·  Verified buyer' : ''}', style: sans(11.5, color: muted)),
            ]),
          ),
      ]),
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
      action: SnackBarAction(label: 'VIEW BAG', onPressed: () => goTab(context, 3)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p, cur = v;
    return SizedBox(
      width: 140,
      child: Column(children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p))),
          child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(4)), child: SizedBox(width: 140, height: 180, child: Photo(p.images.first, width: 320))),
        ),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton(
            onPressed: cur == null ? null : _add,
            style: FilledButton.styleFrom(
                backgroundColor: added ? emerald : wine,
                minimumSize: const Size(0, 42),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(4))),
                padding: EdgeInsets.zero),
            child: Text(added ? '✓ ADDED' : 'ADD'),
          ),
        ),
        const SizedBox(height: 8),
        Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: sans(12.5, height: 1.25)),
        const SizedBox(height: 6),
        if (ok.length > 1)
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: wine), borderRadius: BorderRadius.circular(4)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Variant>(
                value: cur,
                isDense: true,
                style: sans(13.5, weight: FontWeight.w700, color: wine),
                items: [for (final x in ok) DropdownMenuItem(value: x, child: Text(x.size))],
                onChanged: (x) => setState(() {
                  v = x;
                  added = false;
                }),
              ),
            ),
          ),
        const SizedBox(height: 6),
        if (cur != null) PriceRow(cur.price, cur.mrp, size: 14, center: true),
      ]),
    );
  }
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
