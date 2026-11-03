import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../main.dart';
import '../models.dart';
import '../state.dart';
import '../screens/product.dart';

class Photo extends StatelessWidget {
  final String src;
  final int width;
  final BoxFit fit;
  const Photo(this.src, {super.key, this.width = 480, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return Container(color: blush);
    return CachedNetworkImage(
      imageUrl: imgUrl(src, width),
      fit: fit,
      placeholder: (_, __) => Container(color: blush),
      errorWidget: (_, __, ___) => CachedNetworkImage(imageUrl: src.startsWith('/') ? '$kSite$src' : src, fit: fit,
          errorWidget: (_, __, ___) => Container(color: blush, child: const Icon(Icons.image_not_supported_outlined, color: muted))),
    );
  }
}

class PriceRow extends StatelessWidget {
  final Product p;
  final double size;
  const PriceRow(this.p, {super.key, this.size = 15});
  @override
  Widget build(BuildContext context) {
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
      Text(rupees(p.price), style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: ink)),
      if (p.mrp > p.price) Text(rupees(p.mrp), style: TextStyle(fontSize: size - 3, color: muted, decoration: TextDecoration.lineThrough)),
      if (p.offPct > 0) Text('${p.offPct}% off', style: TextStyle(fontSize: size - 3, color: const Color(0xFF1F7A4D), fontWeight: FontWeight.w700)),
    ]);
  }
}

class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final wish = context.watch<WishState>();
    final on = wish.ids.contains(p.id);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(fit: StackFit.expand, children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Photo(p.images.isNotEmpty ? p.images.first : '')),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.9)),
                icon: Icon(on ? Icons.favorite : Icons.favorite_border, color: on ? coral : ink, size: 20),
                onPressed: () => wish.toggle(p.id),
              ),
            ),
            if (p.saleName != null && p.saleName!.isNotEmpty)
              Positioned(left: 6, top: 8, child: _tag(p.saleName!, coral))
            else if (p.offPct >= 10)
              Positioned(left: 6, top: 8, child: _tag('${p.offPct}% OFF', wine)),
          ]),
        ),
        const SizedBox(height: 6),
        Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: ink, height: 1.25)),
        const SizedBox(height: 3),
        PriceRow(p, size: 14.5),
        if (p.reviews > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('★ ${p.rating.toStringAsFixed(1)} (${p.reviews})', style: const TextStyle(fontSize: 12, color: Color(0xFFB7791F), fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _tag(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
      child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)));
}

class ProductGrid extends StatelessWidget {
  final List<Product> items;
  final bool shrink;
  const ProductGrid(this.items, {super.key, this.shrink = false});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrink,
      physics: shrink ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 16, childAspectRatio: 0.52),
      itemCount: items.length,
      itemBuilder: (_, i) => ProductCard(items[i]),
    );
  }
}
