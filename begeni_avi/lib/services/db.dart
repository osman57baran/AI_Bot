import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class Db {
  static final _fs = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _users => _fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get _rooms => _fs.collection('rooms');

  static String get myUid => FirebaseAuth.instance.currentUser!.uid;

  // Oyun ayarları
  static const questionSeconds = 20;
  static const revealSeconds = 6;
  static const pointsCorrect = 100;
  static const pointsFooled = 50; // sahibine, yanlış tahmin eden her kişi için

  // ------------------------------------------------------------------ users

  static Future<void> ensureUser(String uid, String name, String photo) async {
    final ref = _users.doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({'name': name, 'photo': photo, 'createdAt': DateTime.now().millisecondsSinceEpoch});
    } else if ((snap.data()?['photo'] ?? '') == '' && photo.isNotEmpty) {
      await ref.update({'photo': photo});
    }
  }

  static Stream<UserProfile?> watchMe() => _users.doc(myUid).snapshots().map(
        (s) => s.exists ? UserProfile.fromMap(s.id, s.data()!) : null,
      );

  static Future<UserProfile?> getUser(String uid) async {
    final s = await _users.doc(uid).get();
    return s.exists ? UserProfile.fromMap(s.id, s.data()!) : null;
  }

  static Future<void> updateName(String name) => _users.doc(myUid).update({'name': name.trim()});

  static Future<void> saveTikTok({
    required String username,
    required String avatar,
    required List<TtVideo> likes,
    required List<TtVideo> reposts,
  }) {
    return _users.doc(myUid).set({
      'ttUser': username,
      'ttAvatar': avatar,
      'likes': likes.take(400).map((v) => v.toMap()).toList(),
      'reposts': reposts.take(200).map((v) => v.toMap()).toList(),
      'syncedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  static Future<void> unlinkTikTok() => _users.doc(myUid).update({
        'ttUser': '',
        'ttAvatar': '',
        'likes': [],
        'reposts': [],
      });

  // ------------------------------------------------------------------ rooms

  static Stream<Room?> watchRoom(String code) =>
      _rooms.doc(code).snapshots().map((s) => s.exists ? Room.fromMap(s.id, s.data()!) : null);

  static Map<String, dynamic> _playerEntry(UserProfile me) => {
        'name': me.name,
        'avatar': me.avatar,
        'score': 0,
        'vc': me.likes.length + me.reposts.length,
      };

  static Future<String> createRoom(UserProfile me) async {
    final rnd = Random();
    for (var i = 0; i < 20; i++) {
      final code = (1000 + rnd.nextInt(9000)).toString();
      final ref = _rooms.doc(code);
      final ok = await _fs.runTransaction((tx) async {
        final s = await tx.get(ref);
        if (s.exists && (s.data()?['status'] != 'end')) return false;
        tx.set(ref, {
          'host': me.uid,
          'status': 'lobby',
          'players': {me.uid: _playerEntry(me)},
          'questions': [],
          'qi': -1,
          'deadline': 0,
          'votes': {},
          'gain': {},
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        return true;
      });
      if (ok) return code;
    }
    throw Exception('Oda kurulamadı, tekrar dene.');
  }

  static Future<void> joinRoom(String code, UserProfile me) async {
    final ref = _rooms.doc(code);
    final s = await ref.get();
    if (!s.exists) throw Exception('Bu kodla bir oda yok.');
    final data = s.data()!;
    final players = data['players'] as Map? ?? {};
    if (data['status'] != 'lobby' && !players.containsKey(me.uid)) {
      throw Exception('Oyun çoktan başladı.');
    }
    if (!players.containsKey(me.uid)) {
      await ref.update({'players.${me.uid}': _playerEntry(me)});
    }
  }

  static Future<void> leaveRoom(String code) async {
    final ref = _rooms.doc(code);
    await _fs.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (!s.exists) return;
      final data = s.data()!;
      final players = Map<String, dynamic>.from(data['players'] as Map? ?? {});
      players.remove(myUid);
      if (players.isEmpty) {
        tx.delete(ref);
        return;
      }
      final upd = <String, dynamic>{'players.$myUid': FieldValue.delete()};
      if (data['host'] == myUid) upd['host'] = players.keys.first;
      tx.update(ref, upd);
    });
  }

  /// Oyuncuların güncel video sayılarını odaya yazar (lobideyken).
  static Future<void> refreshMyEntry(String code, UserProfile me) =>
      _rooms.doc(code).update({'players.${me.uid}.vc': me.likes.length + me.reposts.length});

  /// Host: herkesin beğeni/repostlarından soru havuzu oluşturur ve oyunu başlatır.
  static Future<void> startGame(Room room, int questionCount) async {
    final pool = <String, ({TtVideo v, Set<String> owners, String kind})>{};
    for (final uid in room.players.keys) {
      final u = await getUser(uid);
      if (u == null) continue;
      void add(TtVideo v, String kind) {
        final e = pool[v.id];
        if (e == null) {
          pool[v.id] = (v: v, owners: {uid}, kind: kind);
        } else {
          e.owners.add(uid);
        }
      }

      for (final v in u.likes) {
        add(v, 'like');
      }
      for (final v in u.reposts) {
        add(v, 'repost');
      }
    }
    if (pool.isEmpty) throw Exception('Kimsenin videosu yok. Önce TikTok hesaplarını bağlayın.');

    // Sahiplere göre dengeli seç: her turda farklı birinin videosu gelsin.
    final rnd = Random();
    final byOwner = <String, List<({TtVideo v, Set<String> owners, String kind})>>{};
    for (final e in pool.values) {
      final key = (e.owners.toList()..shuffle(rnd)).first;
      byOwner.putIfAbsent(key, () => []).add(e);
    }
    for (final l in byOwner.values) {
      l.shuffle(rnd);
    }
    final picked = <Question>[];
    final owners = byOwner.keys.toList()..shuffle(rnd);
    while (picked.length < questionCount && byOwner.values.any((l) => l.isNotEmpty)) {
      for (final o in owners) {
        final l = byOwner[o]!;
        if (l.isEmpty || picked.length >= questionCount) continue;
        final e = l.removeLast();
        picked.add(Question(video: e.v, owners: e.owners.toList(), kind: e.kind));
      }
    }
    picked.shuffle(rnd);

    final upd = <String, dynamic>{
      'questions': picked.map((q) => q.toMap()).toList(),
      'qi': 0,
      'status': 'question',
      'votes': {},
      'gain': {},
      'deadline': DateTime.now().millisecondsSinceEpoch + questionSeconds * 1000,
    };
    for (final uid in room.players.keys) {
      upd['players.$uid.score'] = 0;
    }
    await _rooms.doc(room.code).update(upd);
  }

  static Future<void> vote(String code, String guessUid) =>
      _rooms.doc(code).update({'votes.$myUid': guessUid});

  /// Host: turu bitirip puanları dağıtır.
  static Future<void> reveal(String code) async {
    final ref = _rooms.doc(code);
    await _fs.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (!s.exists) return;
      final room = Room.fromMap(s.id, s.data()!);
      if (room.status != 'question') return;
      final q = room.current;
      if (q == null) return;
      final gain = <String, int>{};
      for (final entry in room.votes.entries) {
        if (q.owners.contains(entry.key)) continue; // sahibin oyu sayılmaz
        if (q.owners.contains(entry.value)) {
          gain[entry.key] = (gain[entry.key] ?? 0) + pointsCorrect;
        } else {
          for (final o in q.owners) {
            gain[o] = (gain[o] ?? 0) + pointsFooled;
          }
        }
      }
      final upd = <String, dynamic>{
        'status': 'reveal',
        'gain': gain,
        'deadline': DateTime.now().millisecondsSinceEpoch + revealSeconds * 1000,
      };
      gain.forEach((uid, pts) {
        if (room.players.containsKey(uid)) upd['players.$uid.score'] = FieldValue.increment(pts);
      });
      tx.update(ref, upd);
    });
  }

  /// Host: bir sonraki soruya geçer ya da oyunu bitirir.
  static Future<void> next(String code) async {
    final ref = _rooms.doc(code);
    await _fs.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (!s.exists) return;
      final room = Room.fromMap(s.id, s.data()!);
      if (room.status != 'reveal') return;
      if (room.qi + 1 >= room.questions.length) {
        tx.update(ref, {'status': 'end'});
      } else {
        tx.update(ref, {
          'status': 'question',
          'qi': room.qi + 1,
          'votes': {},
          'gain': {},
          'deadline': DateTime.now().millisecondsSinceEpoch + questionSeconds * 1000,
        });
      }
    });
  }

  static Future<void> backToLobby(String code) => _rooms.doc(code).update({
        'status': 'lobby',
        'questions': [],
        'qi': -1,
        'votes': {},
        'gain': {},
      });
}
