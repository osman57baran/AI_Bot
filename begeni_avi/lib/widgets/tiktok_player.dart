import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../theme.dart';

const _base = 'https://begeniavi.app/';

/// Oynatıcı bu kadar sürede oynamaya başlamazsa yeniden yüklenir.
const _stallTimeout = Duration(seconds: 9);
const _maxRetries = 2;

enum _State { loading, playing, failed }

/// TikTok'un resmi gömülü oynatıcısıyla videoyu oynatır.
///
/// - Oynatıcı doğrudan açılınca TikTok "Server error" veriyor; bu yüzden
///   bir sayfanın içine iframe olarak gömülüyor (oEmbed'in yaptığı gibi).
/// - Oynatıcının gönderdiği olaylar (hazır / oynuyor / hata) dinlenir:
///   takılırsa yeniden yüklenir, video silinmiş/gizliyse [onUnavailable] çağrılır.
class TikTokPlayer extends StatefulWidget {
  const TikTokPlayer({super.key, required this.videoId, this.onUnavailable});
  final String videoId;
  final VoidCallback? onUnavailable;

  @override
  State<TikTokPlayer> createState() => _TikTokPlayerState();
}

class _TikTokPlayerState extends State<TikTokPlayer> {
  late final WebViewController _c;
  _State _state = _State.loading;
  int _retries = 0;
  int _loadSeq = 0; // eski yüklemelerden gelen olayları yok saymak için
  Timer? _stall;
  bool _reported = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('P', onMessageReceived: (m) => _onEvent(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        // Oynatıcının içinden TikTok uygulamasına / başka sayfaya gitmesin
        onNavigationRequest: (r) => (!r.isMainFrame || r.url.startsWith(_base) || r.url.startsWith('about:'))
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onWebResourceError: (e) {
          if (e.isForMainFrame == true) _retry();
        },
      ));
    _init();
  }

  Future<void> _init() async {
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      await p.setMediaPlaybackRequiresUserGesture(false);
    }
    _load();
  }

  @override
  void dispose() {
    _stall?.cancel();
    super.dispose();
  }

  void _load() {
    _stall?.cancel();
    _loadSeq++;
    if (mounted) setState(() => _state = _State.loading);
    _stall = Timer(_stallTimeout, _retry);
    final src = 'https://www.tiktok.com/player/v1/${widget.videoId}'
        '?autoplay=1&loop=1&music_info=0&description=0&rel=0&native_context_menu=0&closed_caption=0';
    _c.loadHtmlString('''<!doctype html>
<html><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}
iframe{border:0;width:100%;height:100%;display:block}</style>
</head><body>
<iframe id="f" src="$src" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen></iframe>
<script>
(function(){
  var seq = $_loadSeq, playing = false, sentErr = false;
  var f = document.getElementById('f');
  function send(o){ o.seq = seq; try { P.postMessage(JSON.stringify(o)); } catch(e){} }
  function cmd(type){ try { f.contentWindow.postMessage({type: type, 'x-tiktok-player': true}, '*'); } catch(e){} }
  window.addEventListener('message', function(e){
    var d = e.data;
    if (typeof d === 'string') { try { d = JSON.parse(d); } catch(x) { return; } }
    if (!d || !d['x-tiktok-player']) return;
    if (d.type === 'onPlayerReady') { cmd('unMute'); cmd('play'); send({t:'ready'}); }
    else if (d.type === 'onCurrentTime' || (d.type === 'onStateChange' && d.value === 1)) {
      if (!playing) { playing = true; send({t:'playing'}); }
    }
    else if (d.type === 'onPlayerError') {
      sentErr = true;
      send({t:'error', code: d.value && d.value.errorType ? d.value.errorType : String(d.value)});
    }
    else if (d.type === 'onError') {
      // Genel hata; ardından genelde ayrıntılı onPlayerError gelir, onu bekle
      setTimeout(function(){ if (!sentErr && !playing) send({t:'error', code: String(d.value)}); }, 700);
    }
  });
})();
</script>
</body></html>''', baseUrl: _base);
  }

  void _onEvent(String raw) {
    if (!mounted) return;
    Map m;
    try {
      m = jsonDecode(raw) as Map;
    } catch (_) {
      return;
    }
    if (m['seq'] != _loadSeq) return;
    switch (m['t']) {
      case 'ready':
        // Oynatıcı hazır. Otomatik oynatma engellenirse kullanıcı kendisi
        // basabilsin diye 3 sn sonra perdeyi kaldır.
        _stall?.cancel();
        _stall = Timer(const Duration(seconds: 3), () {
          if (mounted && _state == _State.loading) setState(() => _state = _State.playing);
        });
      case 'playing':
        _stall?.cancel();
        setState(() => _state = _State.playing);
      case 'error':
        _stall?.cancel();
        if ('${m['code']}'.contains('INVALID')) {
          _fail(unavailable: true); // silinmiş / gizli video
        } else {
          _retry();
        }
    }
  }

  void _retry() {
    if (!mounted || _state == _State.playing) return;
    if (_retries >= _maxRetries) {
      _fail();
      return;
    }
    _retries++;
    _load();
  }

  void _fail({bool unavailable = false}) {
    _stall?.cancel();
    if (!mounted) return;
    setState(() {
      _state = _State.failed;
      _unavailable = unavailable;
    });
    // Sadece video gerçekten yoksa soruyu değiştir; bağlantı sorununda
    // kullanıcı "Tekrar dene" ile kendisi dener.
    if (unavailable && !_reported) {
      _reported = true;
      widget.onUnavailable?.call();
    }
  }

  @override
  void didUpdateWidget(TikTokPlayer old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) {
      _retries = 0;
      _reported = false;
      _unavailable = false;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        color: Colors.black,
        child: Stack(children: [
          Positioned.fill(child: WebViewWidget(controller: _c)),
          if (_state != _State.playing)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: _state == _State.failed
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.videocam_off_outlined, size: 42, color: AppColors.muted),
                        const SizedBox(height: 10),
                        Text(_unavailable ? 'Bu video silinmiş ya da gizli' : 'Video yüklenemedi',
                            style: const TextStyle(color: Colors.white70)),
                        if (_unavailable && widget.onUnavailable != null)
                          const Text('Başka bir videoya geçiliyor…',
                              style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _retries = 0;
                            _load();
                          },
                          child: const Text('Tekrar dene'),
                        ),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 4)),
                        const SizedBox(height: 14),
                        Text(_retries == 0 ? 'Video yükleniyor…' : 'Tekrar deneniyor… ($_retries/$_maxRetries)',
                            style: const TextStyle(color: Colors.white70)),
                      ]),
              ),
            ),
        ]),
      ),
    );
  }
}
