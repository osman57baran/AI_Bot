import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../screens/room_screen.dart';
import '../services/db.dart';
import '../services/social.dart';
import '../theme.dart';
import 'avatar.dart';
import 'fx.dart';

/// Yeşil nokta ile çevrimiçi göstergeli avatar.
class OnlineAvatar extends StatelessWidget {
  const OnlineAvatar({super.key, required this.p, this.size = 44});
  final PublicProfile p;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Avatar(name: p.name, url: p.avatar, size: size),
      if (p.online)
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bg, width: 2.5),
            ),
          ),
        ),
    ]);
  }
}

// ==================================================================== ana sayfa

class FriendsSection extends StatelessWidget {
  const FriendsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Friendship>>(
      stream: Social.watchFriends(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final incoming = all.where((f) => f.incoming).toList();
        final friends = all.where((f) => f.accepted).toList();
        final outgoing = all.where((f) => !f.accepted && !f.incoming).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('ARKADAŞLAR (${friends.length})',
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const AddFriendDialog()),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Ekle'),
            ),
          ]),
          if (Social.myCode.isNotEmpty)
            Pressable(
              onTap: () {
                Clipboard.setData(ClipboardData(text: Social.myCode));
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arkadaş kodun kopyalandı')));
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Arkadaş kodun: ', style: TextStyle(color: AppColors.muted)),
                  TextSpan(
                    text: Social.myCode,
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.cyan),
                  ),
                  const TextSpan(text: '  (dokun, kopyala)', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ])),
              ),
            ),
          for (final f in incoming) _FriendRow(f: f, key: ValueKey(f.id)),
          for (final f in friends) _FriendRow(f: f, key: ValueKey(f.id)),
          for (final f in outgoing) _FriendRow(f: f, key: ValueKey(f.id)),
          if (all.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
              child: const Text(
                'Henüz arkadaşın yok. TikTok kullanıcı adıyla ya da arkadaş koduyla ekle, sonra odaya tek dokunuşla davet et.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
        ]);
      },
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({super.key, required this.f});
  final Friendship f;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: Social.watchProfile(f.other),
      builder: (context, snap) {
        final p = snap.data ?? PublicProfile(uid: f.other, name: '…');
        return SlideIn(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: f.incoming ? AppColors.pink.withValues(alpha: 0.12) : AppColors.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              OnlineAvatar(p: p, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), overflow: TextOverflow.ellipsis),
                  Text(
                    f.incoming
                        ? 'Seni arkadaş olarak eklemek istiyor'
                        : !f.accepted
                            ? 'İstek gönderildi'
                            : p.online
                                ? 'Çevrimiçi'
                                : (p.ttUser.isNotEmpty ? '@${p.ttUser}' : 'Çevrimdışı'),
                    style: TextStyle(fontSize: 12, color: p.online && f.accepted ? AppColors.green : AppColors.muted),
                  ),
                ]),
              ),
              if (f.incoming) ...[
                IconButton(
                  onPressed: () => Social.remove(f.id),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Social.accept(f.id);
                  },
                  child: const Text('Kabul'),
                ),
              ] else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                  onSelected: (_) => Social.remove(f.id),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'x', child: Text(f.accepted ? 'Arkadaşlıktan çıkar' : 'İsteği geri al')),
                  ],
                ),
            ]),
          ),
        );
      },
    );
  }
}

class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key});

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final _c = TextEditingController();
  List<PublicProfile>? _results;
  bool _busy = false;
  final _sent = <String, String>{};

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _busy = true);
    try {
      final r = await Social.search(_c.text);
      if (mounted) setState(() => _results = r);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Arkadaş ekle'),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _c,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'TikTok kullanıcı adı ya da kod',
              suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search)),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (!_busy && _results != null && _results!.isEmpty)
            const Text('Bulunamadı. Arkadaşın uygulamaya girip TikTok\'unu bağlamış olmalı.',
                style: TextStyle(color: AppColors.muted)),
          if (!_busy && _results != null)
            for (final p in _results!)
              Pop(
                from: 0.8,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: OnlineAvatar(p: p, size: 40),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(p.ttUser.isNotEmpty ? '@${p.ttUser}' : p.code),
                  trailing: _sent[p.uid] != null
                      ? Text(_sent[p.uid]!, style: const TextStyle(color: AppColors.green, fontSize: 12))
                      : FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final msg = await Social.addFriend(p.uid);
                            if (mounted) setState(() => _sent[p.uid] = msg);
                          },
                          child: const Text('Ekle'),
                        ),
                ),
              ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
    );
  }
}

// ==================================================================== davet

/// Uygulama açıkken gelen oda davetlerini yakalar ve gösterir.
class InviteListener extends StatefulWidget {
  const InviteListener({super.key, required this.child});
  final Widget child;

  @override
  State<InviteListener> createState() => _InviteListenerState();
}

class _InviteListenerState extends State<InviteListener> {
  StreamSubscription<List<Invite>>? _sub;
  final _shown = <String>{};

  @override
  void initState() {
    super.initState();
    _sub = Social.watchInvites().listen((list) {
      for (final inv in list) {
        if (_shown.add(inv.id)) _show(inv);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _show(Invite inv) async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final join = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'davet',
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (_, a, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
      pageBuilder: (ctx, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF2A1630), Color(0xFF12262B)]),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Avatar(name: inv.fromName, url: inv.fromAvatar, size: 52, ring: AppColors.pink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: inv.fromName, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const TextSpan(text: ' seni oyuna çağırıyor! 🎮'),
                    ]), style: const TextStyle(fontSize: 17)),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Sonra'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Katıl'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
    Social.dismissInvite(inv.id).catchError((_) {});
    if (join != true || !mounted) return;
    try {
      final me = await Db.getUser(Db.myUid);
      if (me == null) return;
      await Db.joinRoom(inv.room, me);
      if (!mounted) return;
      // Başka bir odadaysa oradan çık, davet edilen odaya gir
      Navigator.of(context).popUntil((r) => r.isFirst);
      RoomScreen.open(context, inv.room);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Lobide arkadaşları tek dokunuşla davet etme sayfası.
class InviteFriendsSheet extends StatefulWidget {
  const InviteFriendsSheet({super.key, required this.room});
  final Room room;

  static Future<void> open(BuildContext context, Room room) => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.bg,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => InviteFriendsSheet(room: room),
      );

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet> {
  final _sent = <String>{};
  UserProfile? _me;

  @override
  void initState() {
    super.initState();
    Db.getUser(Db.myUid).then((m) {
      if (mounted) setState(() => _me = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.cardHi, borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 14),
            const Text('Arkadaşlarını davet et', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Uygulaması açık olanlara hemen bildirim düşer', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            Flexible(
              child: StreamBuilder<List<Friendship>>(
                stream: Social.watchFriends(),
                builder: (context, snap) {
                  final friends = (snap.data ?? []).where((f) => f.accepted).toList();
                  if (snap.hasData && friends.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Henüz arkadaşın yok. Ana sayfadan "Ekle" ile arkadaş ekleyebilirsin.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return ListView(shrinkWrap: true, children: [
                    for (final f in friends)
                      StreamBuilder<PublicProfile?>(
                        stream: Social.watchProfile(f.other),
                        builder: (context, ps) {
                          final p = ps.data ?? PublicProfile(uid: f.other, name: '…');
                          final inRoom = widget.room.players.containsKey(f.other);
                          final sent = _sent.contains(f.other);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              OnlineAvatar(p: p, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  Text(p.online ? 'Çevrimiçi' : 'Çevrimdışı',
                                      style: TextStyle(fontSize: 12, color: p.online ? AppColors.green : AppColors.muted)),
                                ]),
                              ),
                              if (inRoom)
                                const Text('Odada ✓', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800))
                              else
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                  child: sent
                                      ? const Padding(
                                          key: ValueKey('s'),
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          child: Text('Gönderildi ✓', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800)),
                                        )
                                      : FilledButton(
                                          key: const ValueKey('b'),
                                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                                          onPressed: _me == null
                                              ? null
                                              : () {
                                                  HapticFeedback.mediumImpact();
                                                  setState(() => _sent.add(f.other));
                                                  Social.invite(f.other, widget.room.code, _me!);
                                                },
                                          child: const Text('Davet et'),
                                        ),
                                ),
                            ]),
                          );
                        },
                      ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
