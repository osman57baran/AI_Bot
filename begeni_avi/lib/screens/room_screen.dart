import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/fx.dart';
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

  // Titreşimlerin her soru için bir kez çalması için
  String _hapticKey = '';
  int _lastTickSec = -1;

  String get _me => Db.myUid;

  @override
  void initState() {
    super.initState();
    Db.getUser(_me).then((me) {
      if (me != null) Db.refreshMyEntry(widget.code, me).catchError((_) {});
    });
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      _hostLoop();
      _countdownHaptics();
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
    if (r == null || _hostBusy) return;
    final isHost = r.host == _me;
    // Oda sahibi uygulamadan düşerse oyun takılmasın: süre 4 sn aşılınca
    // herkes ilerletmeyi dener (işlemler transaction olduğu için güvenli).
    final now = DateTime.now().millisecondsSinceEpoch - (isHost ? 0 : 4000);
    if (!isHost && now < r.deadline) return;
    try {
      _hostBusy = true;
      if (r.status == 'question') {
        final q = r.current;
        if (q == null) return;
        final voters = r.players.keys.where((u) => !q.owners.contains(u));
        final allVoted = voters.every(r.votes.containsKey);
        if (now >= r.deadline || (isHost && allVoted)) await Db.reveal(r.code);
      } else if (r.status == 'reveal' && now >= r.deadline) {
        await Db.next(r.code);
      }
    } catch (_) {
    } finally {
      _hostBusy = false;
    }
  }

  void _countdownHaptics() {
    final r = _room;
    if (r == null || r.status != 'question') return;
    final secs = ((r.deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (secs != _lastTickSec && secs > 0 && secs <= 3 && !r.votes.containsKey(_me)) {
      HapticFeedback.lightImpact();
    }
    _lastTickSec = secs;
  }

  void _revealHaptics(Room room, Question q) {
    final key = '${room.qi}';
    if (_hapticKey == key) return;
    _hapticKey = key;
    final gain = room.lastGain[_me] ?? 0;
    if (gain > 0) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
    } else {
      HapticFeedback.vibrate();
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
          final screen = switch (room.status) {
            'question' || 'reveal' => _game(room),
            'end' => _end(room),
            _ => _lobby(room),
          };
          final kind = room.status == 'reveal' ? 'question' : room.status;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
            ),
            child: KeyedSubtree(key: ValueKey(kind), child: screen),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ lobi

  Widget _lobby(Room room) {
    final isHost = room.host == _me;
    final players = room.players.values.toList();
    final totalVideos = players.fold<int>(0, (s, p) => s + p.videoCount);
    final canStart = players.length >= Db.minPlayers && totalVideos > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Lobi', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Pop(
          from: 0.8,
          child: Pressable(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [AppColors.pink, Color(0xFF8E2DE2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(children: [
                const Text('ODA KODU', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3)),
                Text(room.code, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 12)),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.copy, size: 14, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('Dokun, kopyala, arkadaşlarına at', style: TextStyle(color: Colors.white70)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Text('OYUNCULAR (${players.length})',
              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const Spacer(),
          if (players.length < Db.minPlayers)
            Text('${Db.minPlayers - players.length} kişi daha', style: const TextStyle(color: AppColors.yellow)),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < players.length; i++)
          SlideIn(
            key: ValueKey(players[i].uid),
            delay: Duration(milliseconds: 60 * i),
            child: _lobbyRow(room, players[i]),
          ),
        const SizedBox(height: 20),
        if (isHost) ...[
          const Text('SORU SAYISI', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 10),
          Row(children: [
            for (final n in const [5, 10, 15, 20])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Pressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _questionCount = n);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _questionCount == n ? AppColors.cyan : AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('$n',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _questionCount == n ? AppColors.bg : Colors.white,
                          )),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          Pressable(
            onTap: !canStart || _starting
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: canStart ? const LinearGradient(colors: [AppColors.pink, Color(0xFFFF7A59)]) : null,
                color: canStart ? null : AppColors.card,
              ),
              child: _starting
                  ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : Text(
                      players.length < Db.minPlayers
                          ? 'En az ${Db.minPlayers} kişi gerekli'
                          : totalVideos == 0
                              ? 'Kimsenin TikTok\'u bağlı değil'
                              : 'BAŞLAT 🚀',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: canStart ? Colors.white : AppColors.muted,
                      ),
                    ),
            ),
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

  Widget _lobbyRow(Room room, Player p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.uid == _me ? AppColors.cardHi : AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
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
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite, size: 14, color: AppColors.pink),
              const SizedBox(width: 4),
              Text('${p.videoCount}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ]),
        ]),
      );

  // ------------------------------------------------------------------ oyun

  Widget _game(Room room) {
    final q = room.current;
    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final reveal = room.status == 'reveal';
    final verb = q.kind == 'repost' ? 'repostladı' : 'beğendi';
    final myScore = room.players[_me]?.score ?? 0;
    if (reveal) _revealHaptics(room, q);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
                child: Text('${room.qi + 1} / ${room.questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (q.kind == 'repost' ? AppColors.cyan : AppColors.pink).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(q.kind == 'repost' ? Icons.repeat : Icons.favorite,
                      size: 14, color: q.kind == 'repost' ? AppColors.cyan : AppColors.pink),
                  const SizedBox(width: 4),
                  Text(q.kind == 'repost' ? 'REPOST' : 'BEĞENİ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: q.kind == 'repost' ? AppColors.cyan : AppColors.pink,
                      )),
                ]),
              ),
              const Spacer(),
              CountdownRing(
                deadline: room.deadline,
                totalMs: (reveal ? Db.revealSeconds : Db.questionSeconds) * 1000,
                size: 46,
                color: reveal ? AppColors.muted : null,
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('PUAN', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w800)),
                CountUp(value: myScore, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.yellow)),
              ]),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(alignment: Alignment.center, children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: TikTokPlayer(
                      videoId: q.video.id,
                      onUnavailable: reveal ? null : () => Db.replaceBrokenVideo(room.code, room.qi, q.video.id),
                    ),
                  ),
                ),
                if (reveal && (room.lastGain[_me] ?? 0) > 0) ...[
                  Positioned.fill(child: ConfettiBurst(key: ValueKey('c${room.qi}'))),
                  FloatingGain(key: ValueKey('g${room.qi}'), text: '+${room.lastGain[_me]}'),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey('${room.status}${room.qi}'),
                child: reveal ? _revealPanel(room, q, verb) : _votePanel(room, q, verb),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _votePanel(Room room, Question q, String verb) {
    final voters = room.players.keys.where((u) => !q.owners.contains(u)).toList();
    final votedCount = voters.where(room.votes.containsKey).length;
    final progress = Text('$votedCount / ${voters.length} kişi oy verdi',
        style: const TextStyle(color: AppColors.muted, fontSize: 13));

    if (q.owners.contains(_me)) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.05),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: const Text('🤫', style: TextStyle(fontSize: 46)),
        ),
        const Text('Bu senin videon!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.yellow)),
        const SizedBox(height: 2),
        const Text('Belli etme, herkes tahmin ediyor…', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        progress,
      ]);
    }

    final myVote = room.votes[_me];
    final options = room.players.values.where((p) => p.uid != _me).toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Bunu kim $verb?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final perRow = options.length <= 4 ? options.length.clamp(1, 4) : (options.length <= 6 ? 3 : 4);
        final w = (c.maxWidth - (perRow - 1) * 10) / perRow;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < options.length; i++)
              SizedBox(
                width: w,
                child: Pop(
                  delay: Duration(milliseconds: 50 * i),
                  from: 0.6,
                  child: _voteTile(
                    options[i],
                    selected: myVote == options[i].uid,
                    dimmed: myVote != null && myVote != options[i].uid,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Db.vote(room.code, options[i].uid);
                    },
                  ),
                ),
              ),
          ],
        );
      }),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _LivePoints(deadline: room.deadline, locked: myVote != null, key: ValueKey('lp${room.qi}')),
        const SizedBox(width: 14),
        progress,
      ]),
    ]);
  }

  Widget _voteTile(Player p, {required bool selected, required bool dimmed, required VoidCallback onTap}) {
    return Pressable(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: dimmed ? 0.45 : 1,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? null : AppColors.card,
              gradient: selected ? const LinearGradient(colors: [AppColors.pink, Color(0xFFFF7A59)]) : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected
                  ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                Avatar(name: p.name, url: p.avatar, size: 52),
                if (selected)
                  const Positioned(
                    right: -4,
                    bottom: -4,
                    child: Pop(
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.check, size: 15, color: AppColors.pink),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
        ),
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
      title = myGain > 0 ? 'KANDIRDIN! 😈' : 'SENİ BULDULAR 😅';
      color = myGain > 0 ? AppColors.green : AppColors.yellow;
    } else if (correct) {
      title = 'DOĞRU! 🎯';
      color = AppColors.green;
    } else {
      title = myVote == null ? 'SÜRE DOLDU ⏰' : 'YANLIŞ! ❌';
      color = AppColors.pink;
    }

    final myAt = room.voteTimes[_me] ?? 0;
    final speed = (correct && myAt > 0 && room.qStart > 0) ? (myAt - room.qStart) / 1000 : null;
    final ranking = room.ranking;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Shake(
        enabled: !correct && !(iWasOwner && myGain > 0),
        child: Pop(
          from: 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
            child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          ),
        ),
      ),
      if (speed != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SlideIn(
            delay: const Duration(milliseconds: 300),
            child: Text('⚡ ${speed.toStringAsFixed(1)} sn\'de bildin  •  +$myGain',
                style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w800)),
          ),
        ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < owners.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Pop(
              delay: Duration(milliseconds: 200 + 120 * i),
              child: Avatar(name: owners[i].name, url: owners[i].avatar, size: 50, ring: AppColors.green),
            ),
          ),
        const SizedBox(width: 10),
        Flexible(
          child: SlideIn(
            delay: const Duration(milliseconds: 250),
            child: Text('$ownerNames $verb!',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      // Mini puan tablosu
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ranking.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final p = ranking[i];
            final gain = room.lastGain[p.uid] ?? 0;
            final vote = room.votes[p.uid];
            final isOwner = q.owners.contains(p.uid);
            final ok = vote != null && q.owners.contains(vote);
            return SlideIn(
              delay: Duration(milliseconds: 400 + 80 * i),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                decoration: BoxDecoration(
                  color: p.uid == _me ? AppColors.cardHi : AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOwner ? AppColors.green : (vote == null ? Colors.transparent : (ok ? AppColors.green : AppColors.pink).withValues(alpha: 0.6)),
                    width: 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Avatar(name: p.name, url: p.avatar, size: 40),
                  const SizedBox(width: 8),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CountUp(value: p.score, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      if (gain > 0) ...[
                        const SizedBox(width: 4),
                        Pop(
                          delay: Duration(milliseconds: 600 + 80 * i),
                          child: Text('+$gain',
                              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ],
                    ]),
                    Text(
                      isOwner
                          ? 'sahibi'
                          : vote == null
                              ? 'oy yok'
                              : '→ ${room.players[vote]?.name ?? '?'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOwner ? AppColors.green : (ok ? AppColors.green : AppColors.muted),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------------ son

  Widget _end(Room room) {
    final ranking = room.ranking;
    final isHost = room.host == _me;
    final iWon = ranking.isNotEmpty && ranking.first.uid == _me;
    return Scaffold(
      appBar: AppBar(title: const Text('Sonuçlar', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.all(20), children: [
          if (ranking.isNotEmpty) ...[
            Center(
              child: Pop(
                child: Text(iWon ? 'KAZANDIN! 🏆' : '${ranking.first.name} kazandı! 🏆',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 20),
            _podium(ranking),
            const SizedBox(height: 20),
          ],
          for (var i = 3; i < ranking.length; i++)
            SlideIn(
              delay: Duration(milliseconds: 1200 + 80 * (i - 3)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ranking[i].uid == _me ? AppColors.cardHi : AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  SizedBox(width: 36, child: Text('${i + 1}.', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  Avatar(name: ranking[i].name, url: ranking[i].avatar, size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text(ranking[i].name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                  CountUp(
                    value: ranking[i].score,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.cyan),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 20),
          if (isHost)
            FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Db.backToLobby(room.code);
              },
              child: const Text('Tekrar oyna'),
            )
          else
            const Center(child: Text('Oda sahibi yeni oyun başlatabilir', style: TextStyle(color: AppColors.muted))),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Odadan çık')),
        ]),
        const Positioned.fill(child: ConfettiBurst(count: 120)),
      ]),
    );
  }

  Widget _podium(List<Player> ranking) {
    // Sıra: 2. - 1. - 3.
    const heights = [150.0, 110.0, 80.0];
    const medals = ['🥇', '🥈', '🥉'];
    const colors = [AppColors.yellow, Color(0xFFC0C0D0), Color(0xFFCD8B5A)];
    final order = [1, 0, 2].where((i) => i < ranking.length).toList();
    return SizedBox(
      height: 290,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final i in order)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Pop(
                  delay: Duration(milliseconds: 500 + (2 - i) * 250),
                  child: Avatar(name: ranking[i].name, url: ranking[i].avatar, size: i == 0 ? 72 : 56, ring: colors[i]),
                ),
                const SizedBox(height: 6),
                Text(ranking[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: heights[i]),
                  duration: Duration(milliseconds: 700 + (2 - i) * 250),
                  curve: Curves.easeOutBack,
                  builder: (context, h, _) => Container(
                    height: h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors[i], colors[i].withValues(alpha: 0.35)],
                      ),
                    ),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 8),
                    child: h < 40
                        ? null
                        : Column(children: [
                            Text(medals[i], style: const TextStyle(fontSize: 26)),
                            CountUp(
                              value: ranking[i].score,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.bg),
                            ),
                          ]),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Oy verirken "şu an doğru bilirsen kaç puan" sayacı; zamanla düşer.
class _LivePoints extends StatefulWidget {
  const _LivePoints({super.key, required this.deadline, required this.locked});
  final int deadline;
  final bool locked;

  @override
  State<_LivePoints> createState() => _LivePointsState();
}

class _LivePointsState extends State<_LivePoints> {
  Timer? _t;
  int? _lockedPts;

  int get _now {
    final total = Db.questionSeconds * 1000;
    final elapsed = total - (widget.deadline - DateTime.now().millisecondsSinceEpoch);
    return Db.pointsFor(elapsed);
  }

  @override
  void initState() {
    super.initState();
    if (widget.locked) _lockedPts = _now;
    _t = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted && _lockedPts == null) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_LivePoints old) {
    super.didUpdateWidget(old);
    if (widget.locked && !old.locked) _lockedPts = _now;
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pts = _lockedPts ?? _now;
    final hot = pts >= 70;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (_lockedPts != null ? AppColors.green : (hot ? AppColors.yellow : AppColors.pink)).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _lockedPts != null ? '🔒 $pts puanlık' : '⚡ $pts puan',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: _lockedPts != null ? AppColors.green : (hot ? AppColors.yellow : AppColors.pink),
        ),
      ),
    );
  }
}
