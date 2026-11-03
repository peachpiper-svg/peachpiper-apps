import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'category.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _tile(context, '', 'All styles', s.live.isNotEmpty ? s.live.first.images.first : '', s.live.length),
        for (final c in s.categories)
          _tile(context, c.id, c.name, c.image.isNotEmpty ? c.image : (s.inCategory(c.id).isNotEmpty ? s.inCategory(c.id).first.images.first : ''), s.inCategory(c.id).length),
      ]),
    );
  }

  Widget _tile(BuildContext context, String id, String name, String img, int n) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(id, name))),
          child: Container(
            height: 92,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
            child: Row(children: [
              ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)), child: SizedBox(width: 92, height: 92, child: Photo(img, width: 320))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('$n styles', style: const TextStyle(color: muted, fontSize: 13)),
              ])),
              const Icon(Icons.chevron_right, color: muted),
              const SizedBox(width: 8),
            ]),
          ),
        ),
      );
}
