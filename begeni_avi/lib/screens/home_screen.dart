import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'room_screen.dart';
import 'tiktok_connect_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _autoPrompted = false;
  bool _busy = false;

  void _maybeAutoConnect(UserProfile me) {
    if (_autoPrompted || me.tiktokLinked) return;
    _autoPrompted = true;
    // İlk açılışta TikTok bağlı değilse direkt bağlama ekranını aç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TikTokConnectScreen.open(context);
    });
  }

  Future<void> _createRoom(UserProfile me) async {
    setState(() => _busy = true);
    try {
      final code = await Db.createRoom(me);
      if (mounted) RoomScreen.open(context, code);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom(UserProfile me) async {
    final code = await showDialog<String>(context: context, builder: (_) => const _JoinDialog());
    if (code == null || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Db.joinRoom(code, me);
      if (mounted) RoomScreen.open(context, code);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName(UserProfile me) async {
    final c = TextEditingController(text: me.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adını değiştir'),
        content: TextField(controller: c, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Kaydet')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) await Db.updateName(name);
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: Db.watchMe(),
      builder: (context, snap) {
        final me = snap.data;
        if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        _maybeAutoConnect(me);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Beğeni Avı', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'name') _editName(me);
                  if (v == 'switch') TikTokConnectScreen.open(context, freshLogin: true);
                  if (v == 'unlink') await Db.unlinkTikTok();
                  if (v == 'out') await AuthService.signOut();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'name', child: Text('Adını değiştir')),
                  const PopupMenuItem(value: 'switch', child: Text('Farklı TikTok hesabı bağla')),
                  if (me.tiktokLinked) const PopupMenuItem(value: 'unlink', child: Text('TikTok bağlantısını kaldır')),
                  const PopupMenuItem(value: 'out', child: Text('Çıkış yap')),
                ],
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            _ProfileCard(me: me),
            const SizedBox(height: 16),
            if (!me.tiktokLinked)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: AppColors.bg),
                onPressed: () => TikTokConnectScreen.open(context),
                icon: const Icon(Icons.link),
                label: const Text('TikTok hesabını bağla'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => TikTokConnectScreen.open(context),
                icon: const Icon(Icons.refresh),
                label: const Text('Beğenileri yenile'),
              ),
            const SizedBox(height: 36),
            const Text('OYNA', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : () => _createRoom(me),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Oda kur'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _joinRoom(me),
              icon: const Icon(Icons.login),
              label: const Text('Odaya katıl'),
            ),
            const SizedBox(height: 28),
            const _HowTo(),
          ]),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me});
  final UserProfile me;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF2A1630), Color(0xFF12262B)]),
      ),
      child: Row(children: [
        Avatar(name: me.name, url: me.avatar, size: 72, ring: me.tiktokLinked ? AppColors.pink : null),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (me.tiktokLinked) ...[
              Text('@${me.ttUser}', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 12, children: [
                _stat(Icons.favorite, AppColors.pink, '${me.likes.length}'),
                _stat(Icons.repeat, AppColors.cyan, '${me.reposts.length}'),
              ]),
            ] else
              const Text('TikTok bağlı değil', style: TextStyle(color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(IconData i, Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 16, color: c),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);
}

class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 12, backgroundColor: AppColors.cardHi, child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(color: AppColors.muted))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Nasıl oynanır?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        step('1', 'Herkes TikTok hesabını bağlar.'),
        step('2', 'Biri oda kurar, diğerleri 4 haneli kodla katılır (en az 3 kişi).'),
        step('3', 'Arkadaşlarının beğendiği ve repostladığı videolar sırayla oynar.'),
        step('4', 'Kimin beğendiğini tahmin et: doğru tahmin +100. Video senin ise, yanılan her kişi için +50.'),
      ]),
    );
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Oda kodu'),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 12),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(context, _c.text.trim()),
          child: const Text('Katıl'),
        ),
      ],
    );
  }
}
