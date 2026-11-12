// =====================================================================
//  FIREBASE AYARLARI
//  Firebase Console > Proje Ayarları > Uygulamalarınız > Android
//  uygulamasından bu değerleri kopyalayıp aşağıya yapıştır.
//  (Ayrıntılı adımlar için KURULUM.md dosyasına bak.)
// =====================================================================

class AppConfig {
  /// "Web API Key" (AIza... ile başlar)
  static const firebaseApiKey = 'AIzaSyA8MtFl0wltUiEeKd3mY9vEsQSCC5RRlNI';

  /// "Uygulama Kimliği / App ID" (1:1234567890:android:abc... gibi)
  static const firebaseAppId = '1:747120359820:android:866ac9ff22d5f1e304fea9';

  /// "Proje numarası / Messaging Sender ID" (sadece rakamlar)
  static const firebaseSenderId = '747120359820';

  /// "Proje Kimliği / Project ID" (ör: begeni-avi-12345)
  static const firebaseProjectId = 'begeni-avi-8684d5';

  /// Google ile giriş için "Web client ID"
  /// (Authentication > Sign-in method > Google > Web SDK configuration)
  /// ...apps.googleusercontent.com ile biter
  static const googleWebClientId = '747120359820-0vvlclsp9r0894b4s94o7t65e7742qad.apps.googleusercontent.com';

  static bool get isConfigured => !firebaseApiKey.startsWith('BURAYA');
  static bool get googleConfigured => !googleWebClientId.startsWith('BURAYA');
}
