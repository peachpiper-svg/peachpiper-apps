import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../main.dart';
import '../models.dart';
import '../nav.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'category.dart';
import 'product.dart';
import '../widgets/top_bar.dart';

/// Home – built from Admin → Customize store → Home, the same blocks as the website:
/// announcement, banners, categories, highlights, new arrivals, promos, rails, occasions, story, size help.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final recent = context.watch<RecentState>();
    return Scaffold(
      appBar: ppBar(context, logo: true),
      body: RefreshIndicator(
        color: wine,
        onRefresh: () => s.load(fresh: true),
        child: s.loading && s.products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : s.error != null && s.products.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 140),
                    const Icon(Icons.wifi_off, size: 44, color: muted),
                    const SizedBox(height: 14),
                    Center(child: Text('Could not load the shop', style: serif(24))),
                    const SizedBox(height: 4),
                    Center(child: Text('Check your internet and try again.', style: sans(14, color: muted))),
                    const SizedBox(height: 18),
                    Center(child: OutlinedButton(onPressed: () => s.load(fresh: true), child: const Text('TRY AGAIN'))),
                  ])
                : ListView(children: [
                    _stories(context, s),
                    if (s.announcement.isNotEmpty) _Announcement(s.announcement),
                    const _Banners(),
                    _categories(context, s),
                    _facts(s),
                    SectionTitle((s.home['arrivals_title'] ?? 'New arrivals').toString(), kickerText: 'Just in', onAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen('', 'New arrivals')))),
                    ProductRail(s.newest.take(((s.home['arrivals_count'] as num?)?.toInt() ?? 10).clamp(4, 16).toInt()).toList()),
                    _promos(context, s),
                    ..._rails(context, s),
                    _occasions(context, s),
                    _story(s),
                    if (recent.viewed.length > 1) ...[
                      const SectionTitle('Recently viewed'),
                      ProductRail(recent.viewed.map(s.byId).whereType<Product>().where((p) => p.available).take(10).toList()),
                    ],
                    _help(context, s),
                    _footer(s),
                  ]),
      ),
    );
  }

  /* ---------- round "stories" row at the top, like Libas ---------- */
  Widget _stories(BuildContext context, StoreState s) {
    final cats = s.categories;
    if (cats.isEmpty) return const SizedBox.shrink();
    final items = <(String, String, VoidCallback)>[
      ('New In', s.newest.isNotEmpty ? s.newest.first.images.first : '', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen('', 'New arrivals')))),
      for (final c in cats)
        (c.name, c.image.isNotEmpty ? c.image : (s.inCategory(c.id).isNotEmpty ? s.inCategory(c.id).first.images.first : ''), () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(c.id, c.name)))),
    ];
    return Container(
      color: Colors.white,
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => GestureDetector(
          onTap: items[i].$3,
          child: SizedBox(
            width: 68,
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [coral, gold], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: ClipOval(child: Photo(items[i].$2, width: 160, alignment: const Alignment(0, -.6))),
                ),
              ),
              const SizedBox(height: 6),
              Text(items[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, weight: FontWeight.w600, color: ink)),
            ]),
          ),
        ),
      ),
    );
  }

  /* ---------- shop by category: 3-column grid ---------- */
  Widget _categories(BuildContext context, StoreState s) {
    if (s.categories.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SectionTitle((s.home['cats_title'] ?? 'Shop by category').toString(), kickerText: 'Explore'),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        mainAxisSpacing: 14,
        crossAxisSpacing: 10,
        childAspectRatio: .62,
        children: [
          for (final c in s.categories)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(c.id, c.name))),
              child: Column(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(border: Border.all(color: goldSoft), borderRadius: const BorderRadius.vertical(top: Radius.circular(60), bottom: Radius.circular(6))),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(57), bottom: Radius.circular(4)),
                      child: SizedBox.expand(
                          child: Photo(c.image.isNotEmpty ? c.image : (s.inCategory(c.id).isNotEmpty ? s.inCategory(c.id).first.images.first : ''), width: 320, alignment: const Alignment(0, -.5))),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(c.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: FontWeight.w700, color: wine, height: 1.2)),
              ]),
            ),
        ],
      ),
    ]);
  }

  /* ---------- highlights strip ---------- */
  Widget _facts(StoreState s) {
    final facts = s.homeList('facts').take(4).toList();
    if (facts.isEmpty) return const SizedBox.shrink();
    const icons = [Icons.local_shipping_outlined, Icons.payments_outlined, Icons.autorenew, Icons.verified_outlined];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: goldSoft))),
      child: Row(children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) Container(width: 1, height: 44, color: line),
          Expanded(
            child: Column(children: [
              Icon(icons[i % 4], color: wine, size: 22),
              const SizedBox(height: 6),
              Text((facts[i]['title'] ?? '').toString(), textAlign: TextAlign.center, maxLines: 2, style: sans(11.5, weight: FontWeight.w700, color: wine, height: 1.2)),
            ]),
          ),
        ],
      ]),
    );
  }

  /* ---------- two promo tiles ---------- */
  Widget _promos(BuildContext context, StoreState s) {
    final promos = s.homeList('promos').where((x) => (x['title'] ?? '').toString().isNotEmpty).take(2).toList();
    final tiles = <Widget>[];
    for (final x in promos) {
      final col = (x['collection'] ?? '').toString();
      final list = s.pickFor(col);
      final pic = (x['image'] ?? '').toString().isNotEmpty ? x['image'].toString() : (list.isNotEmpty ? list.first.images.first : '');
      if (pic.isEmpty) continue;
      final from = s.minPrice(list);
      tiles.add(Expanded(
        child: GestureDetector(
          onTap: () => openLink(context, blockLink(x), title: x['title'].toString()),
          child: AspectRatio(
            aspectRatio: 3 / 4.4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(fit: StackFit.expand, children: [
                Photo(pic, width: 720, alignment: const Alignment(0, -.5)),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.4, 1], colors: [Colors.transparent, Color(0xD94A1823)]))),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 14,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(x['title'].toString(), style: serif(24, color: const Color(0xFFFFF4EC), height: 1.0)),
                    if ((x['text'] ?? '').toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text(x['text'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(11.5, color: const Color(0xFFF2D9D2)))),
                    const SizedBox(height: 8),
                    Text('${from > 0 ? 'FROM ${rupees(from)} · ' : ''}SHOP NOW', style: kicker(color: goldSoft, size: 10)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 10), tiles[i]]]),
    );
  }

  /* ---------- product rails (Admin → Home → rails) ---------- */
  List<Widget> _rails(BuildContext context, StoreState s) {
    final out = <Widget>[];
    for (final r in s.homeList('rails')) {
      final title = (r['title'] ?? '').toString(), col = (r['collection'] ?? '').toString();
      if (title.isEmpty || col.isEmpty) continue;
      final list = s.pickFor(col).take(12).toList();
      if (list.length < 3) continue;
      out.add(SectionTitle(title, onAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(col, title)))));
      out.add(ProductRail(list));
    }
    return out;
  }

  /* ---------- shop by occasion ---------- */
  Widget _occasions(BuildContext context, StoreState s) {
    final occ = s.homeList('occasions').where((o) => (o['title'] ?? '').toString().isNotEmpty && o['cats'] is List && (o['cats'] as List).isNotEmpty).take(4).toList();
    final tiles = <Widget>[];
    for (final o in occ) {
      final cats = (o['cats'] as List).map((e) => e.toString()).toList();
      final list = s.live.where((p) => cats.contains(p.category)).toList();
      final pic = (o['image'] ?? '').toString().isNotEmpty ? o['image'].toString() : (list.isNotEmpty ? list.first.images.first : '');
      if (pic.isEmpty || list.isEmpty) continue;
      tiles.add(GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen('', o['title'].toString(), cats: cats))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(fit: StackFit.expand, children: [
            Photo(pic, width: 480, alignment: const Alignment(0, -.5)),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.35, 1], colors: [Colors.transparent, Color(0xCC2B1419)]))),
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['title'].toString(), style: serif(22, color: Colors.white, height: 1)),
                if ((o['text'] ?? '').toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 3), child: Text(o['text'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11, color: const Color(0xFFF2D9D2)))),
              ]),
            ),
          ]),
        ),
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SectionTitle((s.home['occasion_title'] ?? 'Shop by occasion').toString(), kickerText: 'Dress for the day'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3 / 3.6,
        children: tiles,
      ),
    ]);
  }

  /* ---------- brand story ---------- */
  Widget _story(StoreState s) {
    final h = s.home;
    final title = (h['story_title'] ?? '').toString(), text = (h['story_text'] ?? '').toString();
    if (title.isEmpty && text.isEmpty) return const SizedBox.shrink();
    var pic = (h['story_image'] ?? '').toString();
    if (pic.isEmpty) {
      final a = s.pickFor('anarkali');
      pic = a.isNotEmpty ? a.first.images.first : (s.live.length > 1 ? s.live[1].images.first : '');
    }
    return Container(
      margin: const EdgeInsets.only(top: 40),
      color: blush,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
      child: Column(children: [
        if (pic.isNotEmpty)
          Container(
            width: 220,
            height: 280,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(border: Border.all(color: goldSoft), borderRadius: const BorderRadius.vertical(top: Radius.circular(110), bottom: Radius.circular(4))),
            child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(106), bottom: Radius.circular(2)), child: Photo(pic, width: 720, alignment: const Alignment(0, -.5))),
          ),
        const SizedBox(height: 22),
        Text('OUR STORY', style: kicker()),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: serif(32)),
        const SizedBox(height: 10),
        const Ornament(),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: sans(14.5, color: wineSoft, height: 1.6)),
      ]),
    );
  }

  /* ---------- size help on WhatsApp ---------- */
  Widget _help(BuildContext context, StoreState s) {
    final h = s.home;
    final title = (h['help_title'] ?? 'Not sure about your size?').toString();
    final text = (h['help_text'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 36, 16, 0),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(color: wine, borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Text('SIZE HELP', style: kicker(color: goldSoft)),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: serif(28, color: const Color(0xFFFFF4EC))),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: sans(13.5, color: const Color(0xFFF2D9D2), height: 1.5)),
        ],
        const SizedBox(height: 16),
        if (s.whatsapp.isNotEmpty)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFF4EC), side: const BorderSide(color: goldSoft), minimumSize: const Size(220, 48)),
            onPressed: () => launchUrl(Uri.parse('https://wa.me/91${s.whatsapp.replaceAll(RegExp(r'\D'), '')}?text=${Uri.encodeComponent('Hi Peach Piper! Please help me with my size.')}'), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('ASK ON WHATSAPP'),
          ),
      ]),
    );
  }

  Widget _footer(StoreState s) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
        child: Column(children: [
          Image.asset('assets/logo.png', height: 22),
          const SizedBox(height: 10),
          Text('Ethnic wear, designed and finished in Surat', textAlign: TextAlign.center, style: serif(18, italic: true, weight: FontWeight.w500, color: wineSoft)),
          const SizedBox(height: 12),
          const Ornament(width: 80),
        ]),
      );
}

/* ---------- announcement bar ---------- */
class _Announcement extends StatelessWidget {
  final String text;
  const _Announcement(this.text);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: wine,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
        child: Text(text.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, style: kicker(color: const Color(0xFFF5DFC6), size: 10.5)),
      );
}

/* ---------- banner slider: the admin's own photos are shown whole (never cropped), or built from collection photos ---------- */
class _Banners extends StatefulWidget {
  const _Banners();
  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  final ctl = PageController();
  int idx = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !ctl.hasClients) return;
      final n = _list(context.read<StoreState>()).length;
      if (n < 2) return;
      ctl.animateToPage((idx + 1) % n, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    ctl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(StoreState s) {
    final b = s.homeList('banners').where((x) => (x['image'] ?? '').toString().isNotEmpty || (x['title'] ?? '').toString().isNotEmpty).take(5).toList();
    if (b.isNotEmpty) return b;
    /* no banners set yet: one built from the hero text */
    final h = s.home;
    return [
      {'kicker': h['hero_kicker'] ?? '', 'title': h['hero_title'] ?? 'Ethnic wear you will love', 'text': h['hero_text'] ?? '', 'btn': h['btn1_label'] ?? 'Shop now', 'link': h['btn1_link'] ?? '/shop.html', 'collection': ''}
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final list = _list(s);
    final w = MediaQuery.of(context).size.width;
    /* every slide is 4:5 on phones (like the website's mobile banner) */
    final h = (w * 1.25).clamp(380.0, 620.0).toDouble();
    return Column(children: [
      SizedBox(
        height: h,
        child: PageView.builder(
          controller: ctl,
          itemCount: list.length,
          onPageChanged: (i) => setState(() => idx = i),
          itemBuilder: (_, i) => _slide(context, s, list[i], i),
        ),
      ),
      if (list.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < list.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == idx ? 22 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: i == idx ? wine : goldSoft, borderRadius: BorderRadius.circular(6)),
              ),
          ]),
        ),
    ]);
  }

  Widget _slide(BuildContext context, StoreState s, Map<String, dynamic> b, int i) {
    final link = blockLink(b);
    final mob = (b['image_mobile'] ?? '').toString(), desk = (b['image'] ?? '').toString();
    /* the admin's phone banner: shown as designed */
    if (mob.isNotEmpty) {
      return GestureDetector(onTap: () => openLink(context, link, title: (b['title'] ?? '').toString()), child: Photo(mob, width: 1080));
    }
    final col = (b['collection'] ?? '').toString();
    final list = s.pickFor(col);
    final bg = [wine, blush, sand][i % 3];
    final dark = i % 3 == 0;
    final titleC = dark ? const Color(0xFFFFF4EC) : wine, textC = dark ? const Color(0xFFF2D9D2) : wineSoft, kickC = dark ? const Color(0xFFF5C7A9) : gold;
    final from = s.minPrice(list);
    final copy = Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if ((b['kicker'] ?? '').toString().isNotEmpty) Text(b['kicker'].toString().toUpperCase(), style: kicker(color: kickC)),
        const SizedBox(height: 6),
        Text((b['title'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: serif(31, color: titleC, height: 1.02)),
        if ((b['text'] ?? '').toString().isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(b['text'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(13, color: textC, height: 1.45))),
        const SizedBox(height: 14),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 8, children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: coral, foregroundColor: Colors.white, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
            onPressed: () => openLink(context, link, title: (b['title'] ?? '').toString()),
            child: Text(((b['btn'] ?? '').toString().isEmpty ? 'Shop now' : b['btn'].toString()).toUpperCase()),
          ),
          if (from > 0)
            Text.rich(TextSpan(children: [
              TextSpan(text: 'From ', style: sans(13, color: textC)),
              TextSpan(text: rupees(from), style: sans(14, color: titleC, weight: FontWeight.w800)),
            ])),
        ]),
      ]),
    );
    /* the admin's computer banner (wide): shown whole on top, never cut, with the words below */
    if (desk.isNotEmpty) {
      return GestureDetector(
        onTap: () => openLink(context, link, title: (b['title'] ?? '').toString()),
        child: Container(
          color: bg,
          child: Column(children: [
            AspectRatio(aspectRatio: 1920 / 640, child: Photo(desk, width: 1080, fit: BoxFit.cover)),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: copy))),
          ]),
        ),
      );
    }
    /* built from the collection's photos, like the website */
    final pool = list.isNotEmpty ? list : s.live;
    final pics = pool.where((p) => p.images.isNotEmpty).take(3).map((p) => p.images.first).toList();
    return GestureDetector(
      onTap: () => openLink(context, link, title: (b['title'] ?? '').toString()),
      child: Container(
        color: bg,
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var k = 0; k < pics.length; k++) ...[
                  if (k > 0) const SizedBox(width: 8),
                  Expanded(
                    flex: k == 1 ? 5 : 4,
                    child: FractionallySizedBox(
                      heightFactor: k == 1 ? 1 : .86,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            border: Border.all(color: dark ? const Color(0x99F5C7A9) : goldSoft),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(80), bottom: Radius.circular(4))),
                        child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(77), bottom: Radius.circular(2)),
                            child: Photo(pics[k], width: 480, alignment: const Alignment(0, -.5))),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          copy,
        ]),
      ),
    );
  }
}

/// kept for other screens that open a product from a banner id
void openProduct(BuildContext context, Product p) => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p)));
