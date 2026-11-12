import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/tiktok_js.dart';
import '../theme.dart';

const _desktopUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

const _maxLikes = 300;
const _maxReposts = 150;

enum _Step { login, working, done, failed }

/// Uygulama içinde TikTok'a giriş yaptırır, ardından beğenilen ve repost
/// edilen videoları otomatik çekip profile kaydeder.
class TikTokConnectScreen extends StatefulWidget {
  const TikTokConnectScreen({super.key, this.freshLogin = false});

  /// true ise önceki TikTok oturumu silinir (farklı hesap bağlamak için).
  final bool freshLogin;

  static Future<bool?> open(BuildContext context, {bool freshLogin = false}) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => TikTokConnectScreen(freshLogin: freshLogin)),
      );

  @override
  State<TikTokConnectScreen> createState() => _TikTokConnectScreenState();
}

class _TikTokConnectScreenState extends State<TikTokConnectScreen> {
  late final WebViewController _web;
  _Step _step = _Step.login;
  String _status = 'TikTok hesabına giriş yap';
  String? _error;

  String _username = '';
  String _secUid = '';
  String _avatar = '';
  final _likes = <String, TtVideo>{};
  final _reposts = <String, TtVideo>{};
  final _settled = <String>{}; // 'like', 'repost' tamamlananlar
  final _failed = <String>{};

  bool _awaitingProfile = false;
  bool _fallback = false;
  Timer? _poll;
  Timer? _safety;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUA)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('BA', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: _onPageFinished,
        onNavigationRequest: (req) {
          // TikTok uygulamasını açmaya çalışan bağlantıları engelle
          final u = req.url;
          if (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('about:')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ));

    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(true);
      final cookies = WebViewCookieManager();
      final androidCookies = cookies.platform;
      if (androidCookies is AndroidWebViewCookieManager) {
        await androidCookies.setAcceptThirdPartyCookies(platform, true);
      }
      if (widget.freshLogin) await cookies.clearCookies();
    }
    await _web.loadRequest(Uri.parse('https://www.tiktok.com/login'));

    // Giriş yapıldı mı diye düzenli kontrol (TikTok tek sayfa uygulaması,
    // giriş sonrası her zaman sayfa yenilenmiyor).
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_step == _Step.login) _run(jsDetectUser);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _safety?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _later(Duration d, VoidCallback f) => _timers.add(Timer(d, () {
        if (mounted) f();
      }));

  Future<void> _run(String js) async {
    try {
      await _web.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _onPageFinished(String url) async {
    await _run(jsHook);
    if (_step == _Step.login) {
      await _run(jsDetectUser);
    } else if (_awaitingProfile && url.contains('/@')) {
      _awaitingProfile = false;
      // sayfanın verileri yerleşsin
      _later(const Duration(milliseconds: 1500), () async {
        await _run(jsHook);
        if (_fallback) {
          _runFallbackClicks();
        } else {
          await _run(jsReadProfile);
        }
      });
    }
  }

  void _onMessage(String raw) {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['t']) {
      case 'user':
        final u = m['user'];
        if (u is Map && _step == _Step.login && '${u['username'] ?? ''}'.isNotEmpty) {
          _username = '${u['username']}';
          _secUid = '${u['secUid'] ?? ''}';
          _avatar = '${u['avatar'] ?? ''}';
          _startFetching();
        }
      case 'profile':
        final s = '${m['secUid'] ?? ''}';
        if (s.isNotEmpty) _secUid = s;
        if ('${m['avatar'] ?? ''}'.isNotEmpty) _avatar = '${m['avatar']}';
        if (_secUid.isEmpty) {
          _startFallback();
        } else {
          _run(jsFetchLists(_secUid, _maxLikes, _maxReposts));
        }
      case 'items':
        final target = m['kind'] == 'repost' ? _reposts : _likes;
        for (final it in (m['items'] as List? ?? [])) {
          if (it is! Map) continue;
          final v = TtVideo.fromTikTokItem(it);
          if (v != null) target[v.id] = v;
        }
        _updateStatus();
      case 'done':
        _settled.add('${m['kind']}');
        _checkFinished();
      case 'fail':
        _failed.add('${m['kind']}');
        _settled.add('${m['kind']}');
        _checkFinished();
    }
  }

  void _startFetching() {
    setState(() {
      _step = _Step.working;
      _status = '@$_username bağlandı! Videolar çekiliyor…';
    });
    // Her ihtimale karşı en fazla 75 sn bekle
    _safety = Timer(const Duration(seconds: 75), _finish);
    if (_secUid.isEmpty) {
      _awaitingProfile = true;
      _web.loadRequest(Uri.parse('https://www.tiktok.com/@$_username'));
    } else {
      _run(jsFetchLists(_secUid, _maxLikes, _maxReposts));
    }
  }

  void _updateStatus() {
    if (!mounted) return;
    setState(() => _status = '${_likes.length} beğeni, ${_reposts.length} repost bulundu…');
  }

  void _checkFinished() {
    if (_fallback || _step != _Step.working) return;
    if (!_settled.containsAll(['like', 'repost'])) return;
    // Doğrudan API hiç sonuç vermediyse yedek yolu dene
    if (_likes.isEmpty && _failed.contains('like')) {
      _startFallback();
    } else {
      _finish();
    }
  }

  /// Yedek yol: profil sayfasını açıp "Beğenilenler" ve "Repostlar"
  /// sekmelerine tıklatarak sayfanın kendi isteklerini yakala.
  void _startFallback() {
    if (_fallback) return;
    _fallback = true;
    setState(() => _status = 'Videolar profilinden okunuyor…');
    _awaitingProfile = true;
    _web.loadRequest(Uri.parse('https://www.tiktok.com/@$_username'));
  }

  void _runFallbackClicks() {
    _run(jsClickTab('like'));
    _later(const Duration(seconds: 17), () => _run(jsClickTab('repost')));
    _later(const Duration(seconds: 34), _finish);
  }

  Future<void> _finish() async {
    if (_step != _Step.working) return;
    _safety?.cancel();
    if (_likes.isEmpty && _reposts.isEmpty) {
      setState(() {
        _step = _Step.failed;
        _error = 'Hesabında beğenilen ya da repost edilen video bulunamadı.\n\n'
            'TikTok\'ta biraz video beğenip tekrar dene. Sorun sürerse '
            '"Farklı hesapla dene" ile yeniden giriş yap.';
      });
      return;
    }
    setState(() => _status = 'Profiline kaydediliyor…');
    try {
      await Db.saveTikTok(
        username: _username,
        avatar: _avatar,
        likes: _likes.values.toList(),
        reposts: _reposts.values.toList(),
      );
      if (mounted) setState(() => _step = _Step.done);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.failed;
          _error = 'Kaydedilemedi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TikTok Bağla', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: _step == _Step.login
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Container(
                  color: AppColors.card,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.cyan),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Telefon, e-posta ya da kullanıcı adınla giriş yap.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              )
            : null,
      ),
      body: Stack(children: [
        Positioned.fill(child: WebViewWidget(controller: _web)),
        if (_step != _Step.login) Positioned.fill(child: _overlay()),
      ]),
    );
  }

  Widget _overlay() {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_step == _Step.working) ...[
            const SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 6)),
            const SizedBox(height: 28),
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Bu birkaç saniye sürebilir', style: TextStyle(color: AppColors.muted)),
          ],
          if (_step == _Step.done) ...[
            const Icon(Icons.check_circle, size: 88, color: AppColors.green),
            const SizedBox(height: 20),
            Text('@$_username bağlandı!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _countRow(Icons.favorite, AppColors.pink, '${_likes.length} beğenilen video'),
            _countRow(Icons.repeat, AppColors.cyan, '${_reposts.length} repost'),
            const SizedBox(height: 32),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Tamam')),
          ],
          if (_step == _Step.failed) ...[
            const Icon(Icons.error_outline, size: 80, color: AppColors.yellow),
            const SizedBox(height: 16),
            Text(_error ?? 'Bir şeyler ters gitti', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const TikTokConnectScreen(freshLogin: true)),
              ),
              child: const Text('Farklı hesapla dene'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Kapat')),
          ],
        ]),
      ),
    );
  }

  Widget _countRow(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
      );
}
