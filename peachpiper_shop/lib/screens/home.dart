import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'category.dart';
import 'track.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final home = s.site['home'] is Map ? Map<String, dynamic>.from(s.site['home']) : <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/icon.png', height: 34),
        actions: [
          IconButton(tooltip: 'Track order', icon: const Icon(Icons.local_shipping_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackScreen()))),
        ],
      ),
      body: RefreshIndicator(
        color: wine,
        onRefresh: () => s.load(fresh: true),
        child: s.loading && s.products.isEmpty
            ? const Center(child: CircularProgressIndicator(color: wine))
            : s.error != null && s.products.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    const Icon(Icons.wifi_off, size: 48, color: muted),
                    const SizedBox(height: 12),
                    const Center(child: Text('Could not load the shop. Check your internet.', style: TextStyle(color: muted))),
                    const SizedBox(height: 12),
                    Center(child: OutlinedButton(onPressed: () => s.load(fresh: true), child: const Text('Try again'))),
                  ])
                : ListView(children: [
                    if (s.announcement.isNotEmpty)
                      Container(
                          color: coral,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                          child: Text(s.announcement, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                    _hero(context, home, s),
                    _section('Shop by category'),
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: s.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final c = s.categories[i];
                          final cover = c.image.isNotEmpty ? c.image : (s.inCategory(c.id).isNotEmpty ? s.inCategory(c.id).first.images.first : '');
                          return InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(c.id, c.name))),
                            child: SizedBox(
                              width: 76,
                              child: Column(children: [
                                ClipOval(child: SizedBox(width: 72, height: 72, child: Photo(cover, width: 160))),
                                const SizedBox(height: 6),
                                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                    _facts(home),
                    _section((home['arrivals_title'] ?? 'New arrivals').toString()),
                    ProductGrid(s.newest.take(8).toList(), shrink: true),
                    _section('Best sellers'),
                    ProductGrid(s.bestsellers.take(8).toList(), shrink: true),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                      child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen('', 'All styles'))), child: const Text('View all styles')),
                    ),
                  ]),
      ),
    );
  }

  Widget _hero(BuildContext context, Map<String, dynamic> home, StoreState s) {
    final img = s.featuredHero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 300,
          child: Stack(fit: StackFit.expand, children: [
            Photo(img, width: 1080),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC1E1A1D)]))),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((home['hero_kicker'] ?? '').toString().toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text((home['hero_title'] ?? 'Ethnic wear you will love').toString(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: wine, minimumSize: const Size(0, 44)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen('', 'All styles'))),
                  child: const Text('Shop now'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _facts(Map<String, dynamic> home) {
    final facts = (home['facts'] is List ? home['facts'] as List : const []).take(4).toList();
    if (facts.isEmpty) return const SizedBox.shrink();
    const icons = [Icons.local_shipping_outlined, Icons.payments_outlined, Icons.swap_horiz, Icons.verified_outlined];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.1,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (var i = 0; i < facts.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
              child: Row(children: [
                Icon(icons[i % 4], color: wine, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((facts[i]['title'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text((facts[i]['text'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: muted)),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.fromLTRB(14, 22, 14, 6), child: Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)));
}
