import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'category.dart';
import 'search.dart';

/// Shop tab: every category as a large editorial tile, plus price edits.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())))],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
        _wide(context, '', 'All styles', 'The full collection', s.live.isNotEmpty ? s.live.first.images.first : '', s.live.length, s.minPrice(s.live)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3 / 4.3,
          children: [
            for (final c in s.categories)
              _tile(context, c.id, c.name, c.image.isNotEmpty ? c.image : (s.inCategory(c.id).isNotEmpty ? s.inCategory(c.id).first.images.first : ''), s.inCategory(c.id).length),
          ],
        ),
        const SectionTitle('Shop by price', padding: EdgeInsets.fromLTRB(0, 34, 0, 16)),
        Row(children: [
          for (final pr in const [499, 999, 1499]) ...[
            if (pr != 499) const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen('under-$pr', 'Under ${rupees(pr * 100)}'))),
                child: Container(
                  height: 92,
                  decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(4), border: Border.all(color: goldSoft)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('UNDER', style: kicker(size: 10)),
                    const SizedBox(height: 2),
                    Text(rupees(pr * 100), style: serif(30)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _wide(BuildContext context, String id, String name, String sub, String img, int n, int from) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(id, name))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 190,
            child: Stack(fit: StackFit.expand, children: [
              Photo(img, width: 1080, alignment: const Alignment(0, -.6)),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xE64A1823), Colors.transparent]))),
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sub.toUpperCase(), style: kicker(color: goldSoft, size: 10)),
                  const SizedBox(height: 4),
                  Text(name, style: serif(34, color: const Color(0xFFFFF4EC))),
                  const SizedBox(height: 6),
                  Text('$n styles${from > 0 ? ' · from ${rupees(from)}' : ''}', style: sans(12.5, color: const Color(0xFFF2D9D2))),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _tile(BuildContext context, String id, String name, String img, int n) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(id, name))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(fit: StackFit.expand, children: [
            Photo(img, width: 480, alignment: const Alignment(0, -.5)),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [.45, 1], colors: [Colors.transparent, Color(0xD92B1419)]))),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, style: serif(23, color: Colors.white, height: 1)),
                const SizedBox(height: 4),
                Text('$n STYLES', style: kicker(color: goldSoft, size: 9.5)),
              ]),
            ),
          ]),
        ),
      );
}
