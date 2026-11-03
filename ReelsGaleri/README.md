# Reels Galeri 🎬

Galerindeki videolardan istediklerini seç, Instagram Reels gibi dikey kaydırarak izle.
**Tamamen çevrimdışı** çalışır — internet izni bile yok. Beğeniler ve yorumlar sadece telefonda saklanır.

## Kurulum
1. [`apk/ReelsGaleri.apk`](apk/ReelsGaleri.apk) dosyasını telefona indir.
2. Dosyaya dokun → "Bilinmeyen kaynaklardan yüklemeye izin ver" de → **Yükle**.
3. Uygulama ilk açılışta galeri (video) izni ister → **İzin ver** (Android 14+'da "Tümüne izin ver" seç ki tüm videoları görsün).

## Özellikler
- **Galeriden Video Seç**: Tüm videolar küçük resimleriyle ızgarada; dokunarak seç, "Tümünü seç" ile hepsini al. 300+ video sorunsuz.
- **Reels'i İzle**: Yukarı/aşağı kaydır, video otomatik oynar ve döngüye girer.
  - Tek dokunuş → durdur / devam
  - Çift dokunuş → ❤ beğen (büyük kalp animasyonu)
  - ❤ butonu → beğen / beğeniyi geri al
  - 💬 butonu → yorumları gör, yorum yaz; yoruma uzun bas → sil
- **Beğendiklerimi İzle**: Sadece beğendiğin videolar.
- **Karışık sırayla oynat** anahtarı.

## Derleme
```bash
cd ReelsGaleri
./gradlew assembleRelease   # Android SDK gerekli
# çıktı: app/build/outputs/apk/release/app-release.apk
```
GitHub'a her push'ta Actions APK'yı da derler (Actions → Reels Galeri APK → Artifacts).

Not: `app/reelsgaleri.keystore` kişisel kullanım için repoda tutuluyor; böylece yeni sürümler eski
sürümün üzerine (beğeni/yorumlar silinmeden) kurulabilir.
