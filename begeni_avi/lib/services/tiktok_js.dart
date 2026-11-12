// TikTok web sayfasının içine enjekte edilen JavaScript parçaları.
// Hepsi sonuçlarını "BA" kanalına JSON olarak gönderir.

/// fetch ve XHR yanıtlarını dinler: beğeni/repost listesi geçerse yakalar.
const jsHook = r'''
(function(){
  if (window.__baHook) return; window.__baHook = true;
  const post = (o) => { try { BA.postMessage(JSON.stringify(o)); } catch(e){} };
  const slim = (it) => ({
    id: it.id,
    desc: it.desc,
    video: { cover: it.video && (it.video.cover || it.video.originCover || it.video.dynamicCover) },
    author: { uniqueId: it.author && it.author.uniqueId }
  });
  window.__baSlim = slim;
  window.__baPost = post;
  const watch = (url, text) => {
    try {
      let kind = null;
      if (url.indexOf('/api/favorite/item_list') >= 0) kind = 'like';
      else if (url.indexOf('/api/repost/item_list') >= 0) kind = 'repost';
      if (!kind || !text) return;
      const j = JSON.parse(text);
      post({ t: 'items', kind: kind, items: (j.itemList || []).map(slim), hasMore: !!j.hasMore });
    } catch (e) {}
  };
  const of = window.fetch;
  window.fetch = function(input, init) {
    const url = typeof input === 'string' ? input : (input && input.url) || '';
    return of.apply(this, arguments).then(function(r) {
      try { if (/item_list/.test(url)) r.clone().text().then(function(t){ watch(url, t); }); } catch (e) {}
      return r;
    });
  };
  const oo = XMLHttpRequest.prototype.open, os = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(m, u) { this.__baU = String(u || ''); return oo.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function() {
    const x = this;
    x.addEventListener('load', function() {
      try { if (/item_list/.test(x.__baU)) watch(x.__baU, x.responseText); } catch (e) {}
    });
    return os.apply(this, arguments);
  };
})();
''';

/// Giriş yapılmış mı? Yapıldıysa kullanıcı adı, secUid ve avatarı döndürür.
const jsDetectUser = r'''
(async function(){
  const post = (o) => { try { BA.postMessage(JSON.stringify(o)); } catch(e){} };
  let user = null;
  try {
    const el = document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__');
    if (el) {
      const d = JSON.parse(el.textContent)['__DEFAULT_SCOPE__'] || {};
      const u = (d['webapp.app-context'] || {}).user;
      if (u && u.uniqueId) {
        let av = u.avatarUri;
        if (Array.isArray(av)) av = av[0];
        user = { username: u.uniqueId, secUid: u.secUid || '', avatar: av || '' };
      }
    }
  } catch (e) {}
  if (!user) {
    try {
      const r = await fetch('/passport/web/account/info/?aid=1459&app_name=tiktok_web', { credentials: 'include' });
      const j = await r.json();
      const d = j && j.data;
      if (d && d.username) user = { username: d.username, secUid: d.sec_user_id || '', avatar: d.avatar_url || '' };
    } catch (e) {}
  }
  post({ t: 'user', user: user });
})();
''';

/// Profil sayfasındaysak secUid'i sayfanın içinden okur.
const jsReadProfile = r'''
(function(){
  const post = (o) => { try { BA.postMessage(JSON.stringify(o)); } catch(e){} };
  try {
    const d = JSON.parse(document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__').textContent)['__DEFAULT_SCOPE__'];
    const u = d['webapp.user-detail'].userInfo.user;
    post({ t: 'profile', secUid: u.secUid, avatar: u.avatarMedium || u.avatarThumb || '' });
  } catch (e) { post({ t: 'profile', secUid: '' }); }
})();
''';

/// Beğeni ve repost listelerini TikTok'un kendi web API'sinden sayfa içinden çeker.
String jsFetchLists(String secUid, int maxLikes, int maxReposts) => '''
(async function(){
  const post = window.__baPost || ((o) => { try { BA.postMessage(JSON.stringify(o)); } catch(e){} });
  const slim = window.__baSlim;
  async function grab(kind, path, max) {
    let cursor = '0', total = 0;
    try {
      for (let i = 0; i < 25 && total < max; i++) {
        const qs = new URLSearchParams({
          aid: '1988', app_name: 'tiktok_web', device_platform: 'web_pc',
          secUid: ${_q(secUid)}, count: '30', cursor: cursor, coverFormat: '2'
        });
        const r = await fetch(path + '?' + qs.toString(), { credentials: 'include' });
        const t = await r.text();
        if (!t) { post({ t: 'fail', kind: kind, why: 'empty' }); return; }
        const j = JSON.parse(t);
        const items = (j.itemList || []).map(slim);
        if (i === 0 && items.length === 0 && j.statusCode && j.statusCode !== 0) {
          post({ t: 'fail', kind: kind, why: 'status ' + j.statusCode }); return;
        }
        total += items.length;
        post({ t: 'items', kind: kind, items: items, hasMore: !!j.hasMore });
        if (!j.hasMore || !items.length) break;
        cursor = String(j.cursor);
        await new Promise(res => setTimeout(res, 400));
      }
      post({ t: 'done', kind: kind, total: total });
    } catch (e) { post({ t: 'fail', kind: kind, why: String(e) }); }
  }
  await grab('like', '/api/favorite/item_list/', $maxLikes);
  await grab('repost', '/api/repost/item_list/', $maxReposts);
})();
''';

/// Yedek yol: profil sayfasında sekmeye tıklayıp aşağı kaydırır,
/// böylece sayfa listeyi kendisi yükler ve [jsHook] yakalar.
String jsClickTab(String kind) => '''
(function(){
  const sel = ${kind == 'like' ? "'[data-e2e=\"liked-tab\"]'" : "'[data-e2e=\"repost-tab\"]'"};
  const el = document.querySelector(sel);
  if (el) el.click();
  let n = 0;
  const iv = setInterval(function(){
    window.scrollTo(0, document.body.scrollHeight);
    if (++n > 12) clearInterval(iv);
  }, 1200);
})();
''';

String _q(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
