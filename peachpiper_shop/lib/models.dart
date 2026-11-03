/// Store data, shaped exactly like /api/store.php answers.
class Variant {
  final String id;
  final String size;
  final int price; // paise, what the customer pays
  final int mrp; // paise, crossed-out price (0 if none)
  final bool available;
  Variant({required this.id, required this.size, required this.price, required this.mrp, required this.available});

  factory Variant.fromJson(Map<String, dynamic> j) {
    final prices = (j['prices'] as List?) ?? const [];
    final p0 = prices.isNotEmpty ? Map<String, dynamic>.from(prices.first as Map) : <String, dynamic>{};
    final amount = (p0['amount'] as num?)?.toInt() ?? 0;
    final sale = (p0['sale_amount'] as num?)?.toInt();
    String size = (j['title'] ?? '').toString();
    for (final o in (j['options'] as List?) ?? const []) {
      if ((o['name'] ?? '').toString().toLowerCase() == 'size') size = (o['value'] ?? size).toString();
    }
    return Variant(
      id: j['id'].toString(),
      size: size,
      price: sale != null && sale < amount ? sale : amount,
      mrp: sale != null && sale < amount ? amount : 0,
      available: j['available'] == true,
    );
  }
}

class Product {
  final String id, title, description, category, video, createdAt;
  final List<String> images;
  final List<Variant> variants;
  final String tags;
  final bool featured;
  final String? saleName;
  double rating = 0;
  int reviews = 0;
  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.images,
    required this.variants,
    required this.tags,
    required this.featured,
    required this.video,
    required this.createdAt,
    this.saleName,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'].toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        images: ((j['images'] as List?) ?? const []).map((e) => e.toString()).toList(),
        variants: ((j['variants'] as List?) ?? const []).map((v) => Variant.fromJson(Map<String, dynamic>.from(v as Map))).toList(),
        tags: (j['tags'] ?? '').toString(),
        featured: j['featured'] == true,
        video: (j['video'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        saleName: j['sale'] is Map ? (j['sale']['name'] ?? '').toString() : null,
      );

  bool get available => variants.any((v) => v.available);
  int get price => variants.isEmpty ? 0 : variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  int get mrp {
    final m = variants.where((v) => v.mrp > 0).map((v) => v.mrp);
    return m.isEmpty ? 0 : m.reduce((a, b) => a > b ? a : b);
  }

  int get offPct => mrp > price && mrp > 0 ? ((mrp - price) * 100 / mrp).round() : 0;
  /// set by StoreState, the same way the website builds /products/<slug>
  String slug = '';
  static String slugify(String t) {
    var s = t.toLowerCase().replaceAll('&', ' and ').replaceAll(RegExp(r"['’]"), '').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.length > 90) s = s.substring(0, 90);
    return s.isEmpty ? 'product' : s;
  }
  String get colour {
    final m = RegExp(r'(^|,)color:([^,]+)').firstMatch(tags);
    return m == null ? '' : m.group(2)!.trim();
  }

  bool get hasSizes => variants.length > 1 || (variants.isNotEmpty && variants.first.size.isNotEmpty && variants.first.size.toLowerCase() != 'default title');
}

class Category {
  final String id, name, image;
  Category(this.id, this.name, this.image);
}

class BagLine {
  final String productId, variantId, title, size, image;
  final int price;
  int qty;
  BagLine({required this.productId, required this.variantId, required this.title, required this.size, required this.image, required this.price, this.qty = 1});

  Map<String, dynamic> toJson() => {'p': productId, 'v': variantId, 't': title, 's': size, 'i': image, 'pr': price, 'q': qty};
  factory BagLine.fromJson(Map<String, dynamic> j) => BagLine(
      productId: j['p'], variantId: j['v'], title: j['t'], size: j['s'] ?? '', image: j['i'] ?? '', price: (j['pr'] as num).toInt(), qty: (j['q'] as num).toInt());
  Map<String, dynamic> toOrderItem() => {'product_id': productId, 'variant_id': variantId, 'quantity': qty};
}

class Offer {
  final String code, type;
  final int value, minQty, minTotal;
  final bool first;
  Offer(this.code, this.type, this.value, this.minQty, this.minTotal, this.first);
  String get label => type == 'percent' ? '$value% off' : '₹${(value / 100).round()} off';
}
