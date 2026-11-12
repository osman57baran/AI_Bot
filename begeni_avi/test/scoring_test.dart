import 'package:begeni_avi/models.dart';
import 'package:begeni_avi/services/db.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hızlı cevap daha çok puan getirir', () {
    expect(Db.pointsFor(0), 100);
    expect(Db.pointsFor(10000), 60);
    expect(Db.pointsFor(20000), 20);
    expect(Db.pointsFor(99999), 20); // süre aşımı alt sınırda kalır
    expect(Db.pointsFor(-500), 100); // saat farkı negatif çıkarsa
    expect(Db.pointsFor(2000) > Db.pointsFor(5000), isTrue);
  });

  test('oda verisi zaman damgalarıyla okunur', () {
    final room = Room.fromMap('1234', {
      'host': 'a',
      'status': 'question',
      'players': {'a': {'name': 'Ali', 'score': 40}},
      'questions': [
        {'v': {'id': '1'}, 'o': ['a'], 'k': 'like'}
      ],
      'qi': 0,
      'deadline': 0,
      'votes': {'b': 'a'},
      'vt': {'b': Timestamp.fromMillisecondsSinceEpoch(5000)},
      'qStart': Timestamp.fromMillisecondsSinceEpoch(2000),
      'gain': {'b': 85},
    });
    expect(room.qStart, 2000);
    expect(room.voteTimes['b'], 5000);
    expect(room.lastGain['b'], 85);
    expect(room.current!.owners, ['a']);
  });

  test('sahibi de oy verir; kandırma puanı sadece başkalarının hatasından', () {
    Room room(Map<String, String> votes, Map<String, int> times) => Room.fromMap('1', {
          'host': 'a',
          'status': 'question',
          'players': {'a': {}, 'b': {}, 'c': {}},
          'questions': [
            {'v': {'id': '1'}, 'o': ['a'], 'k': 'like'}
          ],
          'qi': 0,
          'votes': votes,
          'vt': times.map((k, v) => MapEntry(k, Timestamp.fromMillisecondsSinceEpoch(v))),
          'qStart': Timestamp.fromMillisecondsSinceEpoch(1000),
        });

    // a (sahibi) kendini 1 sn'de bildi, b yanıldı, c 11 sn'de bildi
    var r = room({'a': 'a', 'b': 'c', 'c': 'a'}, {'a': 2000, 'b': 3000, 'c': 12000});
    var g = Db.computeGains(r, r.current!);
    expect(g['a'], 96 + 50); // hatırlama puanı + b'yi kandırma
    expect(g['b'], isNull);
    expect(g['c'], 56);

    // a kendi beğenisini unuttu: kendine kandırma puanı vermez
    r = room({'a': 'b'}, {'a': 2000});
    g = Db.computeGains(r, r.current!);
    expect(g, isEmpty);
  });

  test('geçme için çoğunluk gerekir', () {
    expect(Db.skipThreshold(2), 1);
    expect(Db.skipThreshold(3), 2);
    expect(Db.skipThreshold(4), 2);
    expect(Db.skipThreshold(5), 3);
  });
}
