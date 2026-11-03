import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../screens/product.dart';

class Photo extends StatelessWidget {
  final String src;
  final int width;
  final BoxFit fit;
  final Alignment alignment;
  const Photo(this.src, {super.key, this.width = 480, this.fit = BoxFit.cover, this.alignment = Alignment.center});
  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return Container(color: blush);
    return CachedNetworkImage(
      imageUrl: imgUrl(src, width),
      fit: fit,
      alignment: alignment,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => Container(color: blush),
      errorWidget: (_, __, ___) => CachedNetworkImage(
          imageUrl: src.startsWith('/') ? '$kSite$src' : src,
          fit: fit,
          alignment: alignment,
          errorWidget: (_, __, ___) => Container(color: blush, child: const Icon(Icons.image_not_supported_outlined, color: muted))),
    );
  }
}

/// ₹1,299  ₹2,499  48% off
class PriceRow extends StatelessWidget {
  final int now, was;
  final double size;
  final bool center;
  const PriceRow(this.now, this.was, {super.key, this.size = 14.5, this.center = false});
  factory PriceRow.of(Product p, {double size = 14.5, bool center = false}) => PriceRow(p.price, p.mrp, size: size, center: center);
  @override
  Widget build(BuildContext context) {
    final off = was > now && was > 0 ? ((was - now) * 100 / was).round() : 0;
    return Wrap(alignment: center ? WrapAlignment.center : WrapAlignment.start, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
      Text(rupees(now), style: sans(size, weight: FontWeight.w800, color: wine)),
      if (off > 0) Text(rupees(was), style: sans(size - 2.5, color: muted).copyWith(decoration: TextDecoration.lineThrough, decorationColor: muted)),
      if (off > 0) Text('$off% OFF', style: sans(size - 3.5, weight: FontWeight.w800, color: coralDark, spacing: .4)),
    ]);
  }
}

bool _isNew(Product p) {
  final d = DateTime.tryParse(p.createdAt.replaceFirst(' ', 'T'));
  return d != null && DateTime.now().difference(d).inDays <= 21;
}

/// The shop card: tall photo, heart, a small label, name and price – like the website.
class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final wish = context.watch<WishState>();
    final on = wish.ids.contains(p.id);
    final label = (p.saleName ?? '').isNotEmpty ? p.saleName! : (_isNew(p) ? 'NEW' : (p.featured ? 'BESTSELLER' : ''));
    final showRating = p.reviews >= 50 && p.rating >= 4.2;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(fit: StackFit.expand, children: [
              Photo(p.images.isNotEmpty ? p.images.first : '', alignment: const Alignment(0, -.4)),
              if (!p.available)
                Container(color: Colors.white.withValues(alpha: .55), alignment: Alignment.center, child: Text('SOLD OUT', style: kicker(color: wine, size: 12))),
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  onTap: () => wish.toggle(p.id),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), shape: BoxShape.circle),
                    child: Icon(on ? Icons.favorite : Icons.favorite_border, color: on ? coral : wine, size: 18),
                  ),
                ),
              ),
              if (label.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
                    color: label == 'NEW' ? wine : coral,
                    child: Text(label.toUpperCase(), style: kicker(color: Colors.white, size: 9.5)),
                  ),
                ),
              if (showRating)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(3)),
                    child: Text('${p.rating.toStringAsFixed(1)} ★  ${p.reviews}', style: sans(11, weight: FontWeight.w700, color: wine)),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, color: ink, weight: FontWeight.w500)),
        const SizedBox(height: 3),
        PriceRow.of(p, size: 14),
      ]),
    );
  }
}

class ProductGrid extends StatelessWidget {
  final List<Product> items;
  final bool shrink;
  const ProductGrid(this.items, {super.key, this.shrink = false});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 16 * 2 - 12) / 2;
      final ratio = w / (w * 4 / 3 + 58);
      return GridView.builder(
        shrinkWrap: shrink,
        physics: shrink ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 22, childAspectRatio: ratio),
        itemCount: items.length,
        itemBuilder: (_, i) => ProductCard(items[i]),
      );
    });
  }
}

/// a horizontal row of cards (home rails, "you may also like", recently viewed)
class ProductRail extends StatelessWidget {
  final List<Product> items;
  final double width;
  const ProductRail(this.items, {super.key, this.width = 152});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: width * 4 / 3 + 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: width, child: ProductCard(items[i])),
      ),
    );
  }
}
