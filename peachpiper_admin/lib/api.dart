import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kSite = 'https://peachpiper.com';

class ApiError implements Exception {
  final String message;
  final bool auth;
  ApiError(this.message, {this.auth = false});
  @override
  String toString() => message;
}

/// The web admin's own API (/admin/api.php) with the session cookie "ppadmin" + the X-CSRF token from /admin/app-login.php.
class Api {
  Api._();
  static final Api I = Api._();
  String cookie = '';
  String csrf = '';
  String name = '', role = '', store = '';

  Future<bool> restore() async {
    final p = await SharedPreferences.getInstance();
    cookie = p.getString('cookie') ?? '';
    if (cookie.isEmpty) return false;
    try {
      final r = await _post('/admin/app-login.php', {'a': 'session'});
      _session(r);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final r = await _post('/admin/app-login.php', {'email': email, 'password': password});
    _session(r);
  }

  Future<void> logout() async {
    try {
      await _post('/admin/app-login.php', {'a': 'logout'});
    } catch (_) {}
    cookie = '';
    csrf = '';
    final p = await SharedPreferences.getInstance();
    await p.remove('cookie');
  }

  void _session(dynamic r) {
    csrf = (r['csrf'] ?? '').toString();
    name = (r['user']?['name'] ?? '').toString();
    role = (r['user']?['role'] ?? '').toString();
    store = (r['store'] ?? '').toString();
  }

  Future<void> _keep(http.Response r) async {
    final sc = r.headers['set-cookie'] ?? '';
    final m = RegExp(r'ppadmin=([^;,\s]+)').firstMatch(sc);
    if (m != null && m.group(1) != 'deleted') {
      cookie = 'ppadmin=${m.group(1)}';
      final p = await SharedPreferences.getInstance();
      await p.setString('cookie', cookie);
    }
  }

  Map<String, String> get _h => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'PeachPiperAdmin/1.0 (Flutter)',
        if (cookie.isNotEmpty) 'Cookie': cookie,
        if (csrf.isNotEmpty) 'X-CSRF': csrf,
      };

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$kSite$path'), headers: _h, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    await _keep(r);
    return _decode(r);
  }

  /// action = the web admin action name, e.g. "orders.list"
  Future<dynamic> get(String action, [Map<String, String> q = const {}]) async {
    final u = Uri.parse('$kSite/admin/api.php').replace(queryParameters: {'a': action, ...q});
    final r = await http.get(u, headers: _h).timeout(const Duration(seconds: 30));
    await _keep(r);
    return _decode(r);
  }

  Future<dynamic> post(String action, Map<String, dynamic> body) async {
    final u = Uri.parse('$kSite/admin/api.php').replace(queryParameters: {'a': action});
    final r = await http.post(u, headers: _h, body: jsonEncode(body)).timeout(const Duration(seconds: 40));
    await _keep(r);
    return _decode(r);
  }

  dynamic _decode(http.Response r) {
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiError('The server sent an unexpected reply (HTTP ${r.statusCode}).');
    }
    if (r.statusCode == 401) throw ApiError((j is Map ? j['error'] : null)?.toString() ?? 'Log in again', auth: true);
    if (r.statusCode >= 400 || (j is Map && j['error'] != null)) throw ApiError((j is Map ? j['error'] : 'Error').toString());
    return j;
  }
}

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

String imgUrl(String u, [int w = 160]) {
  if (u.isEmpty) return '';
  if (u.startsWith('/media/')) {
    final b = base64Url.encode(utf8.encode(u)).replaceAll('=', '');
    return '$kSite/img/$w/$b';
  }
  return u.startsWith('/') ? '$kSite$u' : u;
}

/// "2026-11-02 12:53:34" (UTC) → "2 Nov, 6:23 pm" (India time)
String when(String utc) {
  final d = DateTime.tryParse('${utc.replaceFirst(' ', 'T')}Z');
  if (d == null) return utc;
  final l = d.toUtc().add(const Duration(hours: 5, minutes: 30));
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '${l.day} ${m[l.month - 1]}, $h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}';
}
