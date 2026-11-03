import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import '../widgets/top_bar.dart';

/// Wishlist tab: saved pieces; the heart on any photo adds or removes them.
class WishlistScreen extends StatelessWidget {
  final bool tab;
  const WishlistScreen({super.key, this.tab = false});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final wish = context.watch<WishState>();
    final items = s.products.where((p) => wish.ids.contains(p.id)).toList();
    return Scaffold(
      appBar: ppBar(context, title: 'Wishlist', sub: items.isEmpty ? null : '${items.length} saved', wishIcon: false),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.favorite_border, color: coral, size: 40),
                  const SizedBox(height: 14),
                  Text('Your wishlist is empty', style: serif(28)),
                  const SizedBox(height: 8),
                  Text('Tap the heart on any style to keep it here for later.', textAlign: TextAlign.center, style: sans(14, color: muted)),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: () => goTab(context, 1), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('EXPLORE STYLES'))),
                ]),
              ),
            )
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Align(alignment: Alignment.centerLeft, child: Text('${items.length} SAVED', style: kicker(color: muted, size: 10))),
              ),
              Expanded(child: ProductGrid(items)),
            ]),
    );
  }
}
