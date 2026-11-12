import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _base = 'https://begeniavi.app/';

/// TikTok'un resmi gömülü oynatıcısıyla videoyu oynatır.
///
/// Oynatıcı doğrudan açılınca TikTok "Server error" veriyor; bu yüzden
/// bir sayfanın içine iframe olarak gömülüyor (oEmbed'in yaptığı gibi).
class TikTokPlayer extends StatefulWidget {
  const TikTokPlayer({super.key, required this.videoId});
  final String videoId;

  @override
  State<TikTokPlayer> createState() => _TikTokPlayerState();
}

class _TikTokPlayerState extends State<TikTokPlayer> {
  late final WebViewController _c;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          // iframe'in içi de yüklensin diye biraz bekle
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) setState(() => _loading = false);
          });
        },
        // Oynatıcının içinden TikTok uygulamasına / başka sayfaya gitmesin
        onNavigationRequest: (r) => (!r.isMainFrame || r.url.startsWith(_base) || r.url.startsWith('about:'))
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
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

  void _load() {
    final src = 'https://www.tiktok.com/player/v1/${widget.videoId}'
        '?autoplay=1&loop=1&music_info=0&description=0&rel=0&native_context_menu=0&closed_caption=0';
    _c.loadHtmlString('''<!doctype html>
<html><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}
iframe{border:0;width:100%;height:100%;display:block}</style>
</head><body>
<iframe src="$src" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen></iframe>
</body></html>''', baseUrl: _base);
  }

  @override
  void didUpdateWidget(TikTokPlayer old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) {
      setState(() => _loading = true);
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
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _loading ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 4)),
                  SizedBox(height: 14),
                  Text('Video yükleniyor…', style: TextStyle(color: Colors.white70)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
