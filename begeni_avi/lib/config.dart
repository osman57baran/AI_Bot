// =====================================================================
//  FIREBASE AYARLARI
//  Firebase Console > Proje Ayarları > Uygulamalarınız > Android
//  uygulamasından bu değerleri kopyalayıp aşağıya yapıştır.
//  (Ayrıntılı adımlar için KURULUM.md dosyasına bak.)
// =====================================================================

class AppConfig {
  /// "Web API Key" (AIza... ile başlar)
  static const firebaseApiKey = 'BURAYA_API_KEY';

  /// "Uygulama Kimliği / App ID" (1:1234567890:android:abc... gibi)
  static const firebaseAppId = 'BURAYA_APP_ID';

  /// "Proje numarası / Messaging Sender ID" (sadece rakamlar)
  static const firebaseSenderId = 'BURAYA_SENDER_ID';

  /// "Proje Kimliği / Project ID" (ör: begeni-avi-12345)
  static const firebaseProjectId = 'BURAYA_PROJECT_ID';

  /// Google ile giriş için "Web client ID"
  /// (Authentication > Sign-in method > Google > Web SDK configuration)
  /// ...apps.googleusercontent.com ile biter
  static const googleWebClientId = 'BURAYA_WEB_CLIENT_ID';

  static bool get isConfigured => !firebaseApiKey.startsWith('BURAYA');
}
