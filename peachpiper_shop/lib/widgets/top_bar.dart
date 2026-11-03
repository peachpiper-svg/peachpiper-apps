import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../screens/bag.dart';
import '../screens/search.dart';
import '../screens/wishlist.dart';

/// The top bar used on every main screen (like the big fashion apps): logo or title, then search, wishlist and bag.
PreferredSizeWidget ppBar(BuildContext context, {String? title, String? sub, bool logo = false, bool wishIcon = true}) {
  return AppBar(
    toolbarHeight: 56,
    centerTitle: false,
    titleSpacing: logo ? 16 : null,
    title: logo
        ? Image.asset('assets/logo.png', height: 24)
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(17, weight: FontWeight.w700, color: ink)),
            if (sub != null) Text(sub, style: sans(11.5, color: muted)),
          ]),
    actions: [
      IconButton(tooltip: 'Search', icon: const Icon(Icons.search, size: 25), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
      if (wishIcon) const _WishIcon(),
      const _BagIcon(),
      const SizedBox(width: 4),
    ],
    bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
  );
}

class _WishIcon extends StatelessWidget {
  const _WishIcon();
  @override
  Widget build(BuildContext context) {
    final n = context.watch<WishState>().ids.length;
    return IconButton(
      tooltip: 'Wishlist',
      icon: Badge(isLabelVisible: n > 0, backgroundColor: coral, label: Text('$n', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), child: const Icon(Icons.favorite_border, size: 24)),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
    );
  }
}

class _BagIcon extends StatelessWidget {
  const _BagIcon();
  @override
  Widget build(BuildContext context) {
    final n = context.watch<BagState>().count;
    return IconButton(
      tooltip: 'Bag',
      icon: Badge(isLabelVisible: n > 0, backgroundColor: coral, label: Text('$n', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), child: const Icon(Icons.shopping_bag_outlined, size: 24)),
      onPressed: () => openBag(context),
    );
  }
}

void openBag(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const BagScreen()));
