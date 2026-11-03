import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'state.dart';
import 'screens/category.dart';
import 'screens/product.dart';

/// Opens a website link (from the admin's banners) inside the app:
/// /collections/<id>, /shop.html?max=999, /products/<slug>; anything else opens in the browser.
void openLink(BuildContext context, String link, {String title = ''}) {
  final s = context.read<StoreState>();
  final u = Uri.tryParse(link.trim()) ?? Uri();
  final path = u.path;
  final col = RegExp(r'^/collections/([^/]+)').firstMatch(path);
  if (col != null) {
    final id = col.group(1)!;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(id, title.isNotEmpty ? title : s.categoryName(id))));
    return;
  }
  final prod = RegExp(r'^/products/([^/]+)').firstMatch(path);
  if (prod != null) {
    final slug = prod.group(1)!;
    for (final p in s.products) {
      if (p.slug == slug) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(p)));
        return;
      }
    }
  }
  if (path.isEmpty || path == '/' || path.startsWith('/shop')) {
    final max = int.tryParse(u.queryParameters['max'] ?? '') ?? 0;
    final id = max > 0 ? 'under-$max' : '';
    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(id, title.isNotEmpty ? title : s.categoryName(id))));
    return;
  }
  launchUrl(Uri.parse(link.startsWith('http') ? link : '$kSite$link'), mode: LaunchMode.externalApplication);
}

/// the link of a home block: its own link, else its collection
String blockLink(Map<String, dynamic> b) {
  final l = (b['link'] ?? '').toString();
  if (l.isNotEmpty) return l;
  final c = (b['collection'] ?? '').toString();
  final m = RegExp(r'^under-(\d+)$').firstMatch(c);
  if (m != null) return '/shop.html?max=${m.group(1)}';
  return c.isEmpty ? '/shop.html' : '/collections/$c';
}
