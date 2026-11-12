# Beğeni Avı – Kurulum

Arkadaşlarınla TikTok beğenilerini izleyip kimin beğendiğini tahmin ettiğin Android oyunu.

## Nasıl çalışır?

1. Uygulamaya **Google** ya da **e-posta** ile giriş yapılır (doğrulama yok).
2. İlk açılışta TikTok bağlama ekranı açılır. Kullanıcı uygulamanın içindeki TikTok sayfasından giriş yapar.
3. Uygulama, girilen TikTok oturumuyla kullanıcının **beğendiği** ve **repostladığı** videoları otomatik çeker
   (en fazla 300 beğeni + 150 repost) ve buluttaki profiline kaydeder.
4. Biri **oda kurar**, diğerleri 4 haneli **kodla katılır**.
5. Videolar sırayla oynar, herkes "Bunu kim beğendi?" sorusuna oy verir.
   - Doğru tahmin: **+100**
   - Video senin ise: yanılan her kişi için **+50**

> Not: Videoları çekmek için TikTok'un resmi olmayan web API'si kullanılıyor (resmi API beğenileri vermiyor).
> TikTok sitesini değiştirirse bu kısım bozulabilir ve güncelleme gerekir.
> TikTok girişinde "Google ile giriş" WebView'de çalışmaz; telefon / e-posta / kullanıcı adı ile girilmeli.

## Bir kerelik Firebase kurulumu (~5 dk)

1. https://console.firebase.google.com → **Proje ekle** (ör. `begeni-avi`). Analytics gerekmez.
2. **Android uygulaması ekle**:
   - Paket adı: `com.begeniavi.begeni_avi`
   - SHA-1: `38:CB:7E:3F:75:CF:3E:FA:67:96:1C:71:9B:C6:2F:0C:11:E4:A9:67`
   - `google-services.json` dosyasını indir.
3. **Authentication → Sign-in method**: **E-posta/Şifre** ve **Google**'ı etkinleştir.
4. **Firestore Database → Veritabanı oluştur** (production mode, bölge: `eur3`).
   **Kurallar** sekmesine `firestore.rules` dosyasının içeriğini yapıştır → Yayınla.
5. `google-services.json` içindeki değerleri `lib/config.dart` dosyasına yaz:

| config.dart          | google-services.json                                                     |
|----------------------|--------------------------------------------------------------------------|
| `firebaseApiKey`     | `client[0].api_key[0].current_key`                                       |
| `firebaseAppId`      | `client[0].client_info.mobilesdk_app_id`                                 |
| `firebaseSenderId`   | `project_info.project_number`                                            |
| `firebaseProjectId`  | `project_info.project_id`                                                |
| `googleWebClientId`  | `client[0].oauth_client` içinde `"client_type": 3` olanın `client_id`'si |

(Ya da `google-services.json` dosyasını Claude'a gönder, o doldursun.)

## APK derleme

```bash
flutter pub get
flutter build apk --release
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

### İmza anahtarı (Google ile giriş için önemli)

Google ile giriş, APK'yı imzalayan anahtarın SHA-1'i Firebase'e kayıtlıysa çalışır.
Anahtar güvenlik nedeniyle **git'e konmaz**. Şu iki dosyayı sende sakla:

- `android/app/begeni-avi.jks` (anahtar dosyası)
- `android/key.properties`:

```properties
storePassword=<şifre>
keyPassword=<şifre>
keyAlias=begeniavi
storeFile=begeni-avi.jks
```

Bu dosyalar yoksa APK debug anahtarıyla imzalanır. O zaman o makinedeki debug anahtarının SHA-1'ini
(`keytool -list -v -keystore ~/.android/debug.keystore -storepass android`) Firebase'e eklemen gerekir.
