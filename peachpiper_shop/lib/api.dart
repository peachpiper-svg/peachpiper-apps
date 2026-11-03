import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The live store. Every screen reads the same API the website uses.
const String kSite = 'https://peachpiper.com';

class ApiError implements Exception {
  final String message;
  final Map<String, dynamic>? fields;
  ApiError(this.message, [this.fields]);
  @override
  String toString() => message;
}

/// Small JSON client with a cookie jar, so the customer login (session cookie "ppcust") survives app restarts.
class Api {
  Api._();
  static final Api I = Api._();
  final Map<String, String> _cookies = {};
  String csrf = '';
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('cookies');
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map).forEach((k, v) => _cookies[k.toString()] = v.toString());
      } catch (_) {}
    }
  }

  Future<void> _keep(http.Response r) async {
    final sc = r.headers['set-cookie'];
    if (sc == null || sc.isEmpty) return;
    // several cookies may arrive joined by commas; take name=value of each
    for (final part in sc.split(RegExp(r',(?=\s*[A-Za-z0-9_]+=)'))) {
      final kv = part.split(';').first.trim();
      final i = kv.indexOf('=');
      if (i <= 0) continue;
      final name = kv.substring(0, i), value = kv.substring(i + 1);
      if (value.isEmpty || value == 'deleted') {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('cookies', jsonEncode(_cookies));
  }

  Map<String, String> _headers({bool json = false}) => {
        'Accept': 'application/json',
        'User-Agent': 'PeachPiperApp/1.0 (Flutter)',
        if (json) 'Content-Type': 'application/json',
        if (_cookies.isNotEmpty) 'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
        if (csrf.isNotEmpty) 'X-CSRF': csrf,
      };

  Future<dynamic> get(String path) async {
    await _load();
    final r = await http.get(Uri.parse('$kSite$path'), headers: _headers()).timeout(const Duration(seconds: 25));
    await _keep(r);
    return _decode(r);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    await _load();
    final r = await http
        .post(Uri.parse('$kSite$path'), headers: _headers(json: true), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    await _keep(r);
    return _decode(r);
  }

  dynamic _decode(http.Response r) {
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiError('The store sent an unexpected reply (HTTP ${r.statusCode}). Please try again.');
    }
    if (r.statusCode >= 400 || (j is Map && j['error'] != null)) {
      final m = j is Map ? j : const {};
      throw ApiError((m['error'] ?? 'Something went wrong').toString(),
          m['fields'] is Map ? Map<String, dynamic>.from(m['fields']) : null);
    }
    return j;
  }
}

/// Photos: our own uploads are served resized by /img/<width>/<base64url(path)>, like on the website.
String imgUrl(String u, [int w = 720]) {
  if (u.isEmpty) return '';
  const sizes = [160, 320, 480, 720, 1080, 1600];
  w = sizes.firstWhere((s) => s >= w, orElse: () => 1600);
  if (u.startsWith('https://cdn.shopify.com/')) return '$u${u.contains('?') ? '&' : '?'}width=$w';
  if (u.startsWith('/media/') || RegExp(r'^https://(cdn|assets)\.zyrosite\.com/').hasMatch(u)) {
    final b = base64Url.encode(utf8.encode(u)).replaceAll('=', '');
    return '$kSite/img/$w/$b';
  }
  if (u.startsWith('/')) return '$kSite$u';
  return u;
}

/// ₹ from paise: 64900 → ₹649
String rupees(num paise) {
  final r = (paise / 100).round();
  final s = r.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

String stripHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</p>|</li>|</h\d>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
