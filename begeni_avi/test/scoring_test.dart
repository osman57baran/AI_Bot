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
}
