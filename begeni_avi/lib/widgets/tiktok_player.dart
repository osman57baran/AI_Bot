import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// TikTok'un resmi gömülü oynatıcısıyla videoyu oynatır.
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
          if (mounted) setState(() => _loading = false);
        },
        // Oynatıcının içinden başka sayfaya/uygulamaya gitmesin
        onNavigationRequest: (r) => (!r.isMainFrame || r.url.contains('/player/'))
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
    _c.loadRequest(Uri.parse(
      'https://www.tiktok.com/player/v1/${widget.videoId}'
      '?autoplay=1&loop=1&music_info=0&description=0&rel=0&native_context_menu=0&closed_caption=0',
    ));
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: Stack(children: [
          Positioned.fill(child: WebViewWidget(controller: _c)),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }
}
