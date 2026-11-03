import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../main.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import '../widgets/top_bar.dart';

/// A list of styles: one category, "under-999" price lists, several categories (an occasion) or everything ('').
/// Sort and filter open as sheets from the bar at the bottom, like the big fashion apps.
class CategoryScreen extends StatefulWidget {
  final String id, name;
  final List<String>? cats;
  final bool tab;
  const CategoryScreen(this.id, this.name, {super.key, this.cats, this.tab = false});
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

const _sizeOrder = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '2XL', '3XL', 'XXXL', '4XL', '5XL', '6XL'];
const _sorts = {'pop': 'Recommended', 'new': 'What\'s new', 'low': 'Price: low to high', 'high': 'Price: high to low', 'off': 'Biggest discount'};

class _CategoryScreenState extends State<CategoryScreen> {
  String sort = 'pop';
  Set<String> sizes = {};
  Set<String> catsOn = {};
  int maxPrice = 0;

  @override
  void initState() {
    super.initState();
    if (widget.name == 'New arrivals') sort = 'new';
  }

  List<Product> _base(StoreState s) {
    if (widget.cats != null) return s.live.where((p) => widget.cats!.contains(p.category)).toList();
    return s.pickFor(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final base = _base(s);
    final allSizes = <String>{};
    for (final p in base) {
      if (!p.hasSizes) continue;
      for (final v in p.variants) {
        if (v.available && v.size.isNotEmpty) allSizes.add(v.size);
      }
    }
    final sizeList = allSizes.toList()..sort((a, b) => _rank(a).compareTo(_rank(b)));
    final catList = s.categories.where((c) => base.any((p) => p.category == c.id)).toList();

    var items = base.where((p) {
      if (sizes.isNotEmpty && !p.variants.any((v) => v.available && sizes.contains(v.size))) return false;
      if (catsOn.isNotEmpty && !catsOn.contains(p.category)) return false;
      if (maxPrice > 0 && p.price > maxPrice * 100) return false;
      return true;
    }).toList();
    if (sort == 'low') items.sort((a, b) => a.price.compareTo(b.price));
    if (sort == 'high') items.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'new') items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (sort == 'off') items.sort((a, b) => b.offPct.compareTo(a.offPct));
    if (sort == 'pop') items.sort((a, b) => ((b.featured ? 1000 : 0) + b.reviews).compareTo((a.featured ? 1000 : 0) + a.reviews));
    final nFilters = sizes.length + catsOn.length + (maxPrice > 0 ? 1 : 0);

    return Scaffold(
      appBar: ppBar(context, title: widget.name, sub: '${items.length} styles'),
      body: items.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Nothing here right now', style: serif(24)),
                const SizedBox(height: 8),
                if (nFilters > 0) TextButton(onPressed: () => setState(_clear), child: const Text('CLEAR FILTERS')),
              ]),
            )
          : ProductGrid(items),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 54,
            child: Row(children: [
              Expanded(child: _barBtn(Icons.swap_vert, 'SORT', _sorts[sort]!, () => _sortSheet())),
              Container(width: 1, height: 28, color: line),
              Expanded(child: _barBtn(Icons.tune, nFilters > 0 ? 'FILTER ($nFilters)' : 'FILTER', nFilters > 0 ? 'Applied' : 'Size, price, type', () => _filterSheet(sizeList, catList))),
            ]),
          ),
        ),
      ),
    );
  }

  int _rank(String z) {
    final i = _sizeOrder.indexOf(z.toUpperCase());
    return i < 0 ? 50 + (int.tryParse(z.replaceAll(RegExp(r'\D'), '')) ?? 0) : i;
  }

  void _clear() {
    sizes = {};
    catsOn = {};
    maxPrice = 0;
  }

  Widget _barBtn(IconData i, String t, String sub, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: wine, size: 20),
          const SizedBox(width: 8),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: kicker(color: wine, size: 11.5)),
            Text(sub, style: sans(11, color: muted)),
          ]),
        ]),
      );

  void _sortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 8), child: Text('Sort by', style: serif(26))),
          for (final e in _sorts.entries)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              title: Text(e.value, style: sans(15, weight: sort == e.key ? FontWeight.w700 : FontWeight.w500, color: sort == e.key ? wine : ink)),
              trailing: sort == e.key ? const Icon(Icons.check, color: coral) : null,
              onTap: () {
                setState(() => sort = e.key);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _filterSheet(List<String> sizeList, List<Category> catList) {
    var sz = {...sizes}, cs = {...catsOn}, mp = maxPrice;
    const prices = [499, 799, 999, 1499, 1999, 2999];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 12, 4),
                child: Row(children: [
                  Text('Filter', style: serif(26)),
                  const Spacer(),
                  TextButton(onPressed: () => set(() { sz = {}; cs = {}; mp = 0; }), child: const Text('CLEAR ALL')),
                ]),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(22, 4, 22, 12), children: [
                  if (sizeList.isNotEmpty) ...[
                    Text('SIZE', style: kicker()),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final z in sizeList)
                        _choice(z, sz.contains(z), () => set(() => sz.contains(z) ? sz.remove(z) : sz.add(z))),
                    ]),
                    const SizedBox(height: 22),
                  ],
                  Text('PRICE', style: kicker()),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final pr in prices) _choice('Under ${rupees(pr * 100)}', mp == pr, () => set(() => mp = mp == pr ? 0 : pr)),
                  ]),
                  if (catList.length > 1) ...[
                    const SizedBox(height: 22),
                    Text('TYPE', style: kicker()),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in catList) _choice(c.name, cs.contains(c.id), () => set(() => cs.contains(c.id) ? cs.remove(c.id) : cs.add(c.id))),
                    ]),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        sizes = sz;
                        catsOn = cs;
                        maxPrice = mp;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('SHOW STYLES'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _choice(String t, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: on ? wine : Colors.white, border: Border.all(color: on ? wine : line), borderRadius: BorderRadius.circular(4)),
          child: Text(t, style: sans(13, weight: FontWeight.w700, color: on ? cream : wine)),
        ),
      );
}
