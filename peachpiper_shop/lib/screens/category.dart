import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/product_card.dart';

/// Products of one category ('' = everything), with sort and size filter.
class CategoryScreen extends StatefulWidget {
  final String id, name;
  const CategoryScreen(this.id, this.name, {super.key});
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String sort = 'new';
  String size = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    List<Product> items = widget.id.isEmpty ? s.live : s.inCategory(widget.id);
    final sizes = <String>{};
    for (final p in items) {
      for (final v in p.variants) {
        if (v.available && v.size.isNotEmpty && p.hasSizes) sizes.add(v.size);
      }
    }
    const order = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '2XL', '3XL', 'XXXL', '4XL', '5XL'];
    final sizeList = sizes.toList()..sort((a, b) => (order.indexOf(a) < 0 ? 99 : order.indexOf(a)).compareTo(order.indexOf(b) < 0 ? 99 : order.indexOf(b)));
    if (size.isNotEmpty) items = items.where((p) => p.variants.any((v) => v.available && v.size == size)).toList();
    items = items.toList();
    if (sort == 'low') items.sort((a, b) => a.price.compareTo(b.price));
    if (sort == 'high') items.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'new') items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (sort == 'off') items.sort((a, b) => b.offPct.compareTo(a.offPct));

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(14, 8, 14, 6), children: [
            PopupMenuButton<String>(
              initialValue: sort,
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'new', child: Text('Newest')),
                PopupMenuItem(value: 'low', child: Text('Price: low to high')),
                PopupMenuItem(value: 'high', child: Text('Price: high to low')),
                PopupMenuItem(value: 'off', child: Text('Biggest discount')),
              ],
              child: Chip(avatar: const Icon(Icons.sort, size: 18), label: Text({'new': 'Newest', 'low': 'Price ↑', 'high': 'Price ↓', 'off': 'Discount'}[sort]!)),
            ),
            const SizedBox(width: 8),
            for (final z in sizeList)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(z), selected: size == z, selectedColor: blush, onSelected: (on) => setState(() => size = on ? z : '')),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(alignment: Alignment.centerLeft, child: Text('${items.length} styles', style: const TextStyle(color: muted, fontSize: 13))),
        ),
        Expanded(child: items.isEmpty ? const Center(child: Text('Nothing here right now.', style: TextStyle(color: muted))) : ProductGrid(items)),
      ]),
    );
  }
}
