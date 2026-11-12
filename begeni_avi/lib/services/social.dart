import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

/// Arkadaşlara görünen hafif profil (videolar burada yok).
class PublicProfile {
  PublicProfile({
    required this.uid,
    required this.name,
    this.avatar = '',
    this.code = '',
    this.ttUser = '',
    this.lastSeen = 0,
  });

  final String uid;
  final String name;
  final String avatar;
  final String code;
  final String ttUser;
  final int lastSeen;

  bool get online => DateTime.now().millisecondsSinceEpoch - lastSeen < 150 * 1000;

  factory PublicProfile.fromMap(String uid, Map<String, dynamic> m) => PublicProfile(
        uid: uid,
        name: '${m['name'] ?? 'Oyuncu'}',
        avatar: '${m['avatar'] ?? ''}',
        code: '${m['code'] ?? ''}',
        ttUser: '${m['ttUser'] ?? ''}',
        lastSeen: (m['lastSeen'] as num?)?.toInt() ?? 0,
      );
}

class Friendship {
  Friendship({required this.id, required this.other, required this.from, required this.accepted});
  final String id;
  final String other; // karşı tarafın uid'i
  final String from; // isteği gönderen
  final bool accepted;

  bool get incoming => !accepted && from != Social.myUid;
}

class Invite {
  Invite({required this.id, required this.from, required this.fromName, required this.fromAvatar, required this.room, required this.at});
  final String id;
  final String from;
  final String fromName;
  final String fromAvatar;
  final String room;
  final int at;
}

class Social {
  static final _fs = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _profiles => _fs.collection('profiles');
  static CollectionReference<Map<String, dynamic>> get _friends => _fs.collection('friendships');
  static CollectionReference<Map<String, dynamic>> get _invites => _fs.collection('invites');

  static String get myUid => FirebaseAuth.instance.currentUser!.uid;

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // karışan harfler yok
  static String _lastSynced = '';
  static String? _myCode;

  static String get myCode => _myCode ?? '';

  // ---------------------------------------------------------------- profil

  /// Profil değiştiyse herkese açık profili günceller, arkadaş kodu yoksa üretir.
  static Future<void> syncProfile(UserProfile me) async {
    final key = '${me.name}|${me.avatar}|${me.ttUser}';
    if (key == _lastSynced) return;
    _lastSynced = key;
    final ref = _profiles.doc(me.uid);
    final snap = await ref.get();
    var code = '${snap.data()?['code'] ?? ''}';
    if (code.isEmpty) code = await _newCode();
    _myCode = code;
    await ref.set({
      'name': me.name,
      'avatar': me.avatar,
      'ttUser': me.ttUser,
      'ttLower': me.ttUser.toLowerCase(),
      'code': code,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  static Future<String> _newCode() async {
    final r = Random.secure();
    for (var i = 0; i < 5; i++) {
      final code = List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
      final taken = await _profiles.where('code', isEqualTo: code).limit(1).get();
      if (taken.docs.isEmpty) return code;
    }
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  /// Uygulama açıkken dakikada bir "çevrimiçiyim" der.
  static Future<void> heartbeat() =>
      _profiles.doc(myUid).set({'lastSeen': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));

  static Stream<PublicProfile?> watchProfile(String uid) =>
      _profiles.doc(uid).snapshots().map((s) => s.exists ? PublicProfile.fromMap(s.id, s.data()!) : null);

  /// TikTok kullanıcı adı ya da 6 haneli arkadaş koduyla arar.
  static Future<List<PublicProfile>> search(String raw) async {
    final q = raw.trim().replaceFirst('@', '');
    if (q.isEmpty) return [];
    final results = <String, PublicProfile>{};
    final byCode = await _profiles.where('code', isEqualTo: q.toUpperCase()).limit(5).get();
    final byTt = await _profiles.where('ttLower', isEqualTo: q.toLowerCase()).limit(5).get();
    for (final d in [...byCode.docs, ...byTt.docs]) {
      if (d.id != myUid) results[d.id] = PublicProfile.fromMap(d.id, d.data());
    }
    return results.values.toList();
  }

  // ---------------------------------------------------------------- arkadaşlık

  static String _pairId(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  static Stream<List<Friendship>> watchFriends() => _friends
      .where('users', arrayContains: myUid)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final users = List<String>.from(d.data()['users'] as List);
            return Friendship(
              id: d.id,
              other: users.firstWhere((u) => u != myUid, orElse: () => myUid),
              from: '${d.data()['from']}',
              accepted: d.data()['status'] == 'accepted',
            );
          }).toList());

  /// Arkadaşlık isteği gönderir. Karşı taraf zaten istek attıysa direkt kabul eder.
  static Future<String> addFriend(String otherUid) async {
    final id = _pairId(myUid, otherUid);
    final existing = await _friends.where('users', arrayContains: myUid).get();
    for (final d in existing.docs) {
      if (d.id != id) continue;
      if (d.data()['status'] == 'accepted') return 'Zaten arkadaşsınız';
      if (d.data()['from'] == myUid) return 'İstek zaten gönderildi';
      await accept(id);
      return 'Arkadaş eklendi!';
    }
    await _friends.doc(id).set({
      'users': [myUid, otherUid],
      'from': myUid,
      'status': 'pending',
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    return 'İstek gönderildi';
  }

  static Future<void> accept(String id) => _friends.doc(id).update({'status': 'accepted'});

  static Future<void> remove(String id) => _friends.doc(id).delete();

  // ---------------------------------------------------------------- davet

  static Future<void> invite(String toUid, String roomCode, UserProfile me) => _invites.add({
        'from': myUid,
        'fromName': me.name,
        'fromAvatar': me.avatar,
        'to': toUid,
        'room': roomCode,
        'at': DateTime.now().millisecondsSinceEpoch,
      });

  /// Bana gelen, son 10 dakikadaki davetler.
  static Stream<List<Invite>> watchInvites() => _invites.where('to', isEqualTo: myUid).snapshots().map((s) {
        final cutoff = DateTime.now().millisecondsSinceEpoch - 10 * 60 * 1000;
        final list = <Invite>[];
        for (final d in s.docs) {
          final m = d.data();
          final at = (m['at'] as num?)?.toInt() ?? 0;
          if (at < cutoff) {
            d.reference.delete().catchError((_) {}); // eskiyenleri temizle
            continue;
          }
          list.add(Invite(
            id: d.id,
            from: '${m['from']}',
            fromName: '${m['fromName'] ?? 'Biri'}',
            fromAvatar: '${m['fromAvatar'] ?? ''}',
            room: '${m['room']}',
            at: at,
          ));
        }
        list.sort((a, b) => b.at.compareTo(a.at));
        return list;
      });

  static Future<void> dismissInvite(String id) => _invites.doc(id).delete();
}
