/// TikTok'tan çekilen bir video (beğeni ya da repost).
class TtVideo {
  TtVideo({required this.id, this.cover = '', this.desc = '', this.author = ''});

  final String id;
  final String cover;
  final String desc;
  final String author;

  Map<String, dynamic> toMap() => {'id': id, 'c': cover, 'd': desc, 'a': author};

  factory TtVideo.fromMap(Map m) => TtVideo(
        id: '${m['id']}',
        cover: '${m['c'] ?? ''}',
        desc: '${m['d'] ?? ''}',
        author: '${m['a'] ?? ''}',
      );

  /// TikTok'un web API'sinden gelen "item" nesnesini çevirir.
  static TtVideo? fromTikTokItem(Map item) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final video = item['video'] is Map ? item['video'] as Map : const {};
    final author = item['author'] is Map ? item['author'] as Map : const {};
    var desc = '${item['desc'] ?? ''}';
    if (desc.length > 90) desc = '${desc.substring(0, 90)}…';
    return TtVideo(
      id: id,
      cover: '${video['cover'] ?? video['originCover'] ?? ''}',
      desc: desc,
      author: '${author['uniqueId'] ?? ''}',
    );
  }
}

class UserProfile {
  UserProfile({
    required this.uid,
    required this.name,
    this.photo = '',
    this.ttUser = '',
    this.ttAvatar = '',
    this.likes = const [],
    this.reposts = const [],
    this.syncedAt,
  });

  final String uid;
  final String name;
  final String photo;
  final String ttUser;
  final String ttAvatar;
  final List<TtVideo> likes;
  final List<TtVideo> reposts;
  final DateTime? syncedAt;

  bool get tiktokLinked => ttUser.isNotEmpty;
  String get avatar => ttAvatar.isNotEmpty ? ttAvatar : photo;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) {
    List<TtVideo> list(dynamic v) =>
        v is List ? v.whereType<Map>().map(TtVideo.fromMap).toList() : <TtVideo>[];
    final ts = m['syncedAt'];
    return UserProfile(
      uid: uid,
      name: '${m['name'] ?? 'Oyuncu'}',
      photo: '${m['photo'] ?? ''}',
      ttUser: '${m['ttUser'] ?? ''}',
      ttAvatar: '${m['ttAvatar'] ?? ''}',
      likes: list(m['likes']),
      reposts: list(m['reposts']),
      syncedAt: ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
    );
  }
}

/// Oyundaki bir soru: bir video ve onu beğenen/repostlayan oyuncular.
class Question {
  Question({required this.video, required this.owners, required this.kind});

  final TtVideo video;
  final List<String> owners; // uid listesi
  final String kind; // 'like' | 'repost'

  Map<String, dynamic> toMap() => {'v': video.toMap(), 'o': owners, 'k': kind};

  factory Question.fromMap(Map m) => Question(
        video: TtVideo.fromMap(m['v'] as Map),
        owners: List<String>.from(m['o'] as List),
        kind: '${m['k']}',
      );
}

class Player {
  Player({required this.uid, required this.name, this.avatar = '', this.score = 0, this.videoCount = 0});

  final String uid;
  final String name;
  final String avatar;
  final int score;
  final int videoCount;

  factory Player.fromMap(String uid, Map m) => Player(
        uid: uid,
        name: '${m['name'] ?? 'Oyuncu'}',
        avatar: '${m['avatar'] ?? ''}',
        score: (m['score'] as num?)?.toInt() ?? 0,
        videoCount: (m['vc'] as num?)?.toInt() ?? 0,
      );
}

class Room {
  Room({
    required this.code,
    required this.host,
    required this.status,
    required this.players,
    required this.questions,
    required this.qi,
    required this.deadline,
    required this.votes,
    required this.lastGain,
  });

  final String code;
  final String host;
  /// lobby | question | reveal | end
  final String status;
  final Map<String, Player> players;
  final List<Question> questions;
  final int qi;
  final int deadline; // ms epoch
  final Map<String, String> votes; // oy veren uid -> tahmin edilen uid
  final Map<String, int> lastGain; // son turda kazanılan puanlar

  Question? get current => (qi >= 0 && qi < questions.length) ? questions[qi] : null;

  List<Player> get ranking => players.values.toList()..sort((a, b) => b.score.compareTo(a.score));

  factory Room.fromMap(String code, Map<String, dynamic> m) {
    final players = <String, Player>{};
    (m['players'] as Map? ?? {}).forEach((k, v) => players['$k'] = Player.fromMap('$k', v as Map));
    return Room(
      code: code,
      host: '${m['host']}',
      status: '${m['status'] ?? 'lobby'}',
      players: players,
      questions: (m['questions'] as List? ?? []).whereType<Map>().map(Question.fromMap).toList(),
      qi: (m['qi'] as num?)?.toInt() ?? -1,
      deadline: (m['deadline'] as num?)?.toInt() ?? 0,
      votes: (m['votes'] as Map? ?? {}).map((k, v) => MapEntry('$k', '$v')),
      lastGain: (m['gain'] as Map? ?? {}).map((k, v) => MapEntry('$k', (v as num).toInt())),
    );
  }
}
