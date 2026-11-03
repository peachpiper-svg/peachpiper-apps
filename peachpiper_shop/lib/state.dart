import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';

/// Catalogue, categories, contact and offers from /api/store.php (cached so the app opens instantly).
class StoreState extends ChangeNotifier {
  List<Product> products = [];
  List<Category> categories = [];
  Map<String, dynamic> contact = {};
  Map<String, dynamic> site = {};
  List<Offer> offers = [];
  int prepaidOff = 0;
  bool cod = true, online = false;
  String announcement = '';
  bool loading = true;
  String? error;

  Future<void> load({bool fresh = false}) async {
    final p = await SharedPreferences.getInstance();
    if (!fresh && products.isEmpty) {
      final cached = p.getString('store');
      if (cached != null) {
        try {
          _apply(jsonDecode(cached));
          loading = false;
          notifyListeners();
        } catch (_) {}
      }
    }
    try {
      final d = await Api.I.get('/api/store.php');
      _apply(d);
      error = null;
      await p.setString('store', jsonEncode(d));
    } catch (e) {
      if (products.isEmpty) error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  void _apply(dynamic d) {
    final m = Map<String, dynamic>.from(d as Map);
    products = ((m['products'] as List?) ?? const []).map((x) => Product.fromJson(Map<String, dynamic>.from(x as Map))).toList();
    final slugCount = <String, int>{};
    for (final pr in products) {
      final b = Product.slugify(pr.title);
      slugCount[b] = (slugCount[b] ?? 0) + 1;
    }
    for (final pr in products) {
      final b = Product.slugify(pr.title);
      pr.slug = (slugCount[b] ?? 0) > 1 ? '$b-${pr.id.substring(pr.id.length > 5 ? pr.id.length - 5 : 0).toLowerCase()}' : b;
    }
    final ratings = m['ratings'] is Map ? Map<String, dynamic>.from(m['ratings']) : <String, dynamic>{};
    for (final pr in products) {
      final r = ratings[pr.id];
      if (r is List && r.length >= 2) {
        pr.rating = (r[0] as num).toDouble();
        pr.reviews = (r[1] as num).toInt();
      }
    }
    final counts = <String, int>{};
    for (final pr in products) {
      if (pr.available) counts[pr.category] = (counts[pr.category] ?? 0) + 1;
    }
    categories = ((m['categories'] as List?) ?? const [])
        .map((c) => Category(c['id'].toString(), c['name'].toString(), (c['image'] ?? '').toString()))
        .where((c) => (counts[c.id] ?? 0) > 0)
        .toList();
    contact = m['contact'] is Map ? Map<String, dynamic>.from(m['contact']) : {};
    site = m['site'] is Map ? Map<String, dynamic>.from(m['site']) : {};
    final pay = m['payments'] is Map ? m['payments'] : const {};
    cod = pay['cod'] != false;
    online = pay['online'] == true;
    final of = m['offers'] is Map ? m['offers'] : const {};
    prepaidOff = (of['prepaid'] as num?)?.toInt() ?? 0;
    offers = ((of['codes'] as List?) ?? const [])
        .map((o) => Offer(o['code'].toString(), (o['type'] ?? 'flat').toString(), (o['value'] as num).toInt(), (o['min_qty'] as num?)?.toInt() ?? 0,
            (o['min_total'] as num?)?.toInt() ?? 0, o['first'] == true))
        .toList();
    final ann = site['announcement'];
    announcement = ann is Map ? (ann['text'] ?? '').toString() : (ann ?? '').toString();
  }

  List<Product> get live => products.where((p) => p.available && p.images.isNotEmpty).toList();
  List<Product> inCategory(String id) => live.where((p) => p.category == id).toList();
  List<Product> get newest {
    final l = live.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  List<Product> get bestsellers {
    final l = live.toList()..sort((a, b) => (b.featured ? 1 : 0) * 1000 + b.reviews - ((a.featured ? 1 : 0) * 1000 + a.reviews));
    return l;
  }

  Product? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Product> search(String q) {
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];
    return live.where((p) {
      final hay = '${p.title} ${p.tags} ${p.category}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  /// the home banner: the photo set in Admin → Store → Home, else the first starred product
  String get featuredHero {
    final home = site['home'];
    if (home is Map && home['hero_images'] is List) {
      for (final i in home['hero_images']) {
        if (i is String && i.isNotEmpty) return i;
      }
    }
    for (final p in live) {
      if (p.featured) return p.images.first;
    }
    return live.isNotEmpty ? live.first.images.first : '';
  }

  String get whatsapp => (contact['whatsapp'] ?? contact['phone'] ?? '').toString();
}

/// The bag, kept on the phone.
class BagState extends ChangeNotifier {
  List<BagLine> lines = [];
  String coupon = '';
  int discount = 0;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('bag');
    if (raw != null) {
      try {
        lines = (jsonDecode(raw) as List).map((e) => BagLine.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('bag', jsonEncode(lines.map((l) => l.toJson()).toList()));
    discount = 0;
    coupon = '';
    notifyListeners();
  }

  int get count => lines.fold(0, (a, l) => a + l.qty);
  int get subtotal => lines.fold(0, (a, l) => a + l.price * l.qty);

  void add(Product p, Variant v, {int qty = 1}) {
    final i = lines.indexWhere((l) => l.variantId == v.id);
    if (i >= 0) {
      lines[i].qty = (lines[i].qty + qty).clamp(1, 10);
    } else {
      lines.add(BagLine(productId: p.id, variantId: v.id, title: p.title, size: p.hasSizes ? v.size : '', image: p.images.isNotEmpty ? p.images.first : '', price: v.price, qty: qty));
    }
    _save();
  }

  void setQty(BagLine l, int q) {
    if (q <= 0) {
      lines.remove(l);
    } else {
      l.qty = q.clamp(1, 10);
    }
    _save();
  }

  void clear() {
    lines = [];
    _save();
  }

  Future<String?> applyCoupon(String code, String phone) async {
    try {
      final r = await Api.I.post('/api/coupon.php', {'code': code, 'items': lines.map((l) => l.toOrderItem()).toList(), 'phone': phone});
      coupon = r['code'].toString();
      discount = (r['discount'] as num).toInt();
      notifyListeners();
      return null;
    } catch (e) {
      coupon = '';
      discount = 0;
      notifyListeners();
      return e.toString();
    }
  }
}

/// Wishlist, kept on the phone.
class WishState extends ChangeNotifier {
  Set<String> ids = {};
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    ids = (p.getStringList('wish') ?? const []).toSet();
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('wish', ids.toList());
    notifyListeners();
  }
}

/// Customer login (email one-time code), same account as on the website.
class AccountState extends ChangeNotifier {
  Map<String, dynamic>? customer;
  List<Map<String, dynamic>> orders = [];
  Map<String, dynamic> lastAddress = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('addr');
    if (raw != null) {
      try {
        lastAddress = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }
    try {
      final r = await Api.I.get('/api/account.php?a=me');
      Api.I.csrf = (r['csrf'] ?? '').toString();
      customer = r['customer'] is Map ? Map<String, dynamic>.from(r['customer']) : null;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> rememberAddress(Map<String, dynamic> a) async {
    lastAddress = a;
    final p = await SharedPreferences.getInstance();
    await p.setString('addr', jsonEncode(a));
  }

  Future<void> sendCode(String email) async {
    if (Api.I.csrf.isEmpty) await load();
    await Api.I.post('/api/account.php?a=otp.send', {'email': email});
  }

  Future<void> verify(String email, String code) async {
    final r = await Api.I.post('/api/account.php?a=otp.verify', {'email': email, 'code': code});
    Api.I.csrf = (r['csrf'] ?? '').toString();
    customer = Map<String, dynamic>.from(r['customer']);
    notifyListeners();
    await loadOrders();
  }

  Future<void> loadOrders() async {
    if (customer == null) return;
    try {
      final r = await Api.I.get('/api/account.php?a=orders');
      orders = ((r['orders'] as List?) ?? const []).map((o) => Map<String, dynamic>.from(o)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteAccount() async {
    await Api.I.post('/api/account.php?a=delete', {});
    customer = null;
    orders = [];
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await Api.I.post('/api/account.php?a=logout', {});
    } catch (_) {}
    customer = null;
    orders = [];
    notifyListeners();
  }
}
