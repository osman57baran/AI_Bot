import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/tiktok_player.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.code});
  final String code;

  static Future<void> open(BuildContext context, String code) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(code: code)));

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final Stream<Room?> _stream = Db.watchRoom(widget.code);
  Room? _room;
  Timer? _tick;
  bool _hostBusy = false;
  int _questionCount = 10;
  bool _starting = false;

  String get _me => Db.myUid;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {}); // geri sayımı güncelle
      _hostLoop();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Oyunu odayı kuran telefon yönetir: süre dolunca ya da herkes oy
  /// verince cevabı açar, sonra sıradaki soruya geçer.
  Future<void> _hostLoop() async {
    final r = _room;
    if (r == null || r.host != _me || _hostBusy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      _hostBusy = true;
      if (r.status == 'question') {
        final q = r.current;
        if (q == null) return;
        final voters = r.players.keys.where((u) => !q.owners.contains(u));
        final allVoted = voters.every(r.votes.containsKey);
        if (now >= r.deadline || allVoted) await Db.reveal(r.code);
      } else if (r.status == 'reveal' && now >= r.deadline) {
        await Db.next(r.code);
      }
    } catch (_) {
    } finally {
      _hostBusy = false;
    }
  }

  Future<void> _leave() async {
    try {
      await Db.leaveRoom(widget.code);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: StreamBuilder<Room?>(
        stream: _stream,
        builder: (context, snap) {
          final room = snap.data;
          _room = room;
          if (snap.connectionState == ConnectionState.waiting && room == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (room == null || !room.players.containsKey(_me)) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Oda kapandı.', style: TextStyle(fontSize: 18))),
            );
          }
          return switch (room.status) {
            'question' || 'reveal' => _game(room),
            'end' => _end(room),
            _ => _lobby(room),
          };
        },
      ),
    );
  }

  // ------------------------------------------------------------------ lobi

  Widget _lobby(Room room) {
    final isHost = room.host == _me;
    final players = room.players.values.toList();
    final totalVideos = players.fold<int>(0, (s, p) => s + p.videoCount);
    final canStart = players.length >= 2 && totalVideos > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Lobi', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: room.code));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı')));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [AppColors.pink, Color(0xFF8E2DE2)]),
            ),
            child: Column(children: [
              const Text('ODA KODU', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3)),
              Text(room.code, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 12)),
              const Text('Arkadaşların bu kodla katılsın', style: TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        Text('OYUNCULAR (${players.length})',
            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 10),
        for (final p in players)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Avatar(name: p.name, url: p.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Text(p.name + (p.uid == room.host ? '  👑' : ''),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (p.videoCount == 0)
                const Text('TikTok yok', style: TextStyle(color: AppColors.yellow, fontSize: 13))
              else
                Text('${p.videoCount} video', style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
        const SizedBox(height: 20),
        if (isHost) ...[
          const Text('SORU SAYISI', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 10, label: Text('10')),
              ButtonSegment(value: 15, label: Text('15')),
              ButtonSegment(value: 20, label: Text('20')),
            ],
            selected: {_questionCount},
            onSelectionChanged: (s) => setState(() => _questionCount = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: !canStart || _starting
                ? null
                : () async {
                    setState(() => _starting = true);
                    try {
                      await Db.startGame(room, _questionCount);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                      }
                    } finally {
                      if (mounted) setState(() => _starting = false);
                    }
                  },
            child: Text(players.length < 2 ? 'En az 2 kişi gerekli' : 'Başlat'),
          ),
        ] else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Oda sahibinin başlatması bekleniyor…', style: TextStyle(color: AppColors.muted)),
            ),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------------ oyun

  Widget _game(Room room) {
    final q = room.current!;
    final reveal = room.status == 'reveal';
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = (reveal ? Db.revealSeconds : Db.questionSeconds) * 1000;
    final left = (room.deadline - now).clamp(0, total);
    final verb = q.kind == 'repost' ? 'repostladı' : 'beğendi';

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              Text('${room.qi + 1}/${room.questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: left / total,
                    minHeight: 8,
                    color: reveal ? AppColors.cyan : (left < 5000 ? AppColors.yellow : AppColors.pink),
                    backgroundColor: AppColors.card,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(left / 1000).ceil()}s', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Center(
                child: AspectRatio(aspectRatio: 9 / 16, child: TikTokPlayer(videoId: q.video.id)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: reveal ? _revealPanel(room, q, verb) : _votePanel(room, q, verb),
          ),
        ]),
      ),
    );
  }

  Widget _votePanel(Room room, Question q, String verb) {
    if (q.owners.contains(_me)) {
      return _banner('🤫 Bu senin videon!', 'Belli etme, herkes tahmin ediyor…', AppColors.yellow);
    }
    final myVote = room.votes[_me];
    final players = room.players.values.toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Bunu kim $verb?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final p in players)
            _choice(
              p,
              selected: myVote == p.uid,
              voted: room.votes.containsKey(p.uid),
              onTap: () => Db.vote(room.code, p.uid),
            ),
        ],
      ),
    ]);
  }

  Widget _choice(Player p, {required bool selected, required bool voted, VoidCallback? onTap, Color? highlight}) {
    final color = highlight ?? (selected ? AppColors.pink : AppColors.card);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Avatar(name: p.name, url: p.avatar, size: 34),
          const SizedBox(width: 8),
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (voted && highlight == null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, size: 14, color: AppColors.green),
          ],
        ]),
      ),
    );
  }

  Widget _revealPanel(Room room, Question q, String verb) {
    final owners = q.owners.map((u) => room.players[u]).whereType<Player>().toList();
    final ownerNames = owners.isEmpty ? 'Ayrılan bir oyuncu' : owners.map((p) => p.name).join(' & ');
    final myGain = room.lastGain[_me] ?? 0;
    final iWasOwner = q.owners.contains(_me);
    final myVote = room.votes[_me];
    final correct = myVote != null && q.owners.contains(myVote);

    String title;
    Color color;
    if (iWasOwner) {
      title = myGain > 0 ? 'Kandırdın! +$myGain' : 'Seni buldular 😅';
      color = myGain > 0 ? AppColors.green : AppColors.yellow;
    } else if (correct) {
      title = 'Doğru! +$myGain';
      color = AppColors.green;
    } else {
      title = myVote == null ? 'Süre doldu' : 'Yanlış!';
      color = AppColors.pink;
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final o in owners) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Avatar(name: o.name, url: o.avatar, size: 44, ring: AppColors.green),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text('$ownerNames $verb!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
        ),
      ]),
      const SizedBox(height: 8),
      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (final e in room.votes.entries)
          if (room.players[e.key] != null && !q.owners.contains(e.key))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: q.owners.contains(e.value) ? AppColors.green.withValues(alpha: 0.2) : AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${room.players[e.key]!.name} → ${room.players[e.value]?.name ?? '?'}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
      ]),
    ]);
  }

  Widget _banner(String title, String sub, Color c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: AppColors.muted)),
        ]),
      );

  // ------------------------------------------------------------------ son

  Widget _end(Room room) {
    final ranking = room.ranking;
    final isHost = room.host == _me;
    const medals = ['🥇', '🥈', '🥉'];
    return Scaffold(
      appBar: AppBar(title: const Text('Sonuçlar', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (ranking.isNotEmpty) ...[
          Center(child: Avatar(name: ranking.first.name, url: ranking.first.avatar, size: 110, ring: AppColors.yellow)),
          const SizedBox(height: 12),
          Center(
            child: Text('${ranking.first.name} kazandı!',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 24),
        ],
        for (var i = 0; i < ranking.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ranking[i].uid == _me ? AppColors.cardHi : AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              SizedBox(
                width: 36,
                child: Text(i < 3 ? medals[i] : '${i + 1}.',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              Avatar(name: ranking[i].name, url: ranking[i].avatar, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(ranking[i].name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              Text('${ranking[i].score}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.cyan)),
            ]),
          ),
        const SizedBox(height: 20),
        if (isHost)
          FilledButton(onPressed: () => Db.backToLobby(room.code), child: const Text('Tekrar oyna'))
        else
          const Center(child: Text('Oda sahibi yeni oyun başlatabilir', style: TextStyle(color: AppColors.muted))),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Odadan çık')),
      ]),
    );
  }
}
