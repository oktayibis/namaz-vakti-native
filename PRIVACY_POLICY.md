# Privacy Policy / Gizlilik Politikası / سياسة الخصوصية — Mîkât (Miqat / ميقات)

**Effective Date / Yürürlük Tarihi / تاريخ السريان:** November 20, 2026  
**Developer & Data Controller / Veri Sorumlusu:** Oktay İbiş (`oktayibis@icloud.com`)  
**Apps Covered:** Mîkât (iOS: `com.okib.NamazVakti`, Widget: `com.okib.NamazVakti.NamazVaktiWidget`; Android: `com.oktay.namaz`)  
**Web Version:** https://oktayibis.github.io/namaz-vakti-native/privacy.html

---

## 🇹🇷 Türkçe — Gizlilik Politikası

### 1. Özet Taahhüdümüz

**Mîkât**, kullanıcı mahremiyetine en üst düzeyde saygı göstermek üzere geliştirilmiştir. Bu Gizlilik Politikası; **Apple App Store İnceleme Yönergesi 5.1.1**, **Avrupa Birliği Genel Veri Koruma Tüzüğü (GDPR)** ve **6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK)** ile uyumlu olarak hazırlanmıştır.

| Başlık | Durum | Açıklama |
| :--- | :---: | :--- |
| **Kullanıcı Hesabı / Üyelik** | Yok | Kayıt, giriş, ad-soyad, e-posta veya telefon numarası talep edilmez. |
| **Reklam ve Çapraz Uygulama Takibi** | Sıfır Takip | `NSPrivacyTracking = false`. IDFA kullanılmaz, `AdSupport` veya ATT eklenmemiştir. |
| **GPS Konum Koordinatları** | Yalnızca Cihaz İçi | Yalnızca cihaz içi astronomik hesaplama için kullanılır; sunuculara gönderilmez. |
| **Bildirimler** | %100 Yerel | Uzak bildirim (push) token'ı toplanmaz; tüm alarmlar cihaz içinde planlanır. |
| **Hata ve Kullanım Tanılaması** | Anonim | Firebase Crashlytics & Analytics (reklam kişiselleştirme kapalı); kimliğinizle ilişkilendirilmez. |

### 2. Konum İzni ve Şehir Arama

* **GPS Konumu (`NSLocationWhenInUseUsageDescription`):** Konum izni tamamen isteğe bağlıdır. İzin verdiğinizde enlem ve boylam bilginiz yalnızca cihaz içinde namaz vakitlerini hesaplamak ve işletim sisteminin yerel ters coğrafi kodlama servisi (iOS'ta `CLGeocoder`, Android'de `Geocoder`) aracılığıyla şehir adını ve saat dilimini belirlemek için kullanılır. Hassas GPS koordinatlarınız tarafımızca hiçbir sunucuya gönderilmez ve arka planda konum takibi yapılmaz.
* **Manuel Şehir Arama (Open-Meteo Geocoding API):** Konum izni vermeden dilediğiniz şehri arayabilirsiniz. Arama yaptığınızda yalnızca yazdığınız şehir adı ve dil kodu **Open-Meteo Geocoding API** (`geocoding-api.open-meteo.com`) servisine kişisel tanımlayıcı veya çerez olmaksızın iletilir.

### 3. Cihaz İçi Yerel Depolama (`UserDefaults` & App Group)

Seçtiğiniz şehir, koordinatlar, saat dilimi, hesaplama metodu (Diyanet, MWL vb.), İkindi mezhebi, uygulama dili ve bildirim tercihleriniz yalnızca kendi cihazınızda saklanır. iOS'ta bu veriler, ana uygulama ile Ana Ekran Widget'ının aynı vakitleri gösterebilmesi için App Group (`group.com.okib.namaz`) üzerinden `UserDefaults` içinde tutulur ve Apple Gizlilik Bildirimi'nde (`PrivacyInfo.xcprivacy`) `NSPrivacyAccessedAPICategoryUserDefaults` — `CA92.1` gerekçesiyle beyan edilmiştir.

### 4. Yerel Bildirimler

Tüm namaz vakti hatırlatıcıları %100 yerel olarak cihazınız üzerinde planlanır (iOS'ta `UNUserNotificationCenter`, Android'de `AlarmManager` / `WorkManager`). Uzak sunucu tabanlı anlık bildirim (push notification) kullanılmaz ve cihaz bildirim belirteci (push token) toplanmaz.

### 5. Anonim Çökme Raporları ve Kullanım İstatistikleri

Uygulamanın kararlılığını sağlamak ve hataları gidermek için **Google Firebase Crashlytics** ve **Firebase Analytics** kullanılır:

* Reklam kişiselleştirme sinyalleri devre dışıdır (`GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS = false`) ve IDFA toplanmaz.
* Yalnızca anonim çökme raporları (cihaz modeli, işletim sistemi sürümü, yığın izi) ve kimlikle ilişkilendirilmeyen toplu kullanım olayları (ekran görüntüleme, seçilen şehir/ülke adı — kesin GPS koordinatı olmadan —, dil, hesaplama metodu, mezhep ve bildirim aç/kapa tercihleri) işlenir.
* Veriler hiçbir zaman satılmaz, kiralanmaz veya reklam ağlarıyla paylaşılmaz.

### 6. Veri Saklama, Silme ve Haklarınız (KVKK & GDPR)

Cihazınızda depolanan tüm veriler, uygulamayı kaldırdığınızda veya uygulama verilerini temizlediğinizde anında silinir. Firebase üzerindeki anonim tanılama kayıtları Google Firebase'in standart saklama sürelerine tabidir. KVKK (Madde 11) ve GDPR (Madde 15–22) kapsamındaki erişim, düzeltme, silme ve itiraz haklarınız için bizimle iletişime geçebilirsiniz.

### 7. Çocukların Gizliliği

Mîkât tüm yaş gruplarına uygundur (4+) ve çocuklardan bilerek kişisel kimlik bilgisi toplamaz.

### 8. İletişim

* **Veri Sorumlusu / Geliştirici:** Oktay İbiş
* **E-posta:** oktayibis@icloud.com

---

## 🇬🇧 English — Privacy Policy

### 1. Privacy at a Glance

**Miqat (Mîkât)** is built from the ground up to protect your privacy. This Privacy Policy complies with **Apple App Store Review Guideline 5.1.1**, the **EU General Data Protection Regulation (GDPR)**, and **Türkiye's Law No. 6698 on the Protection of Personal Data (KVKK)**.

| Category | Status | Details |
| :--- | :---: | :--- |
| **User Accounts** | None | No sign-up, login, name, email, or phone number required. |
| **Ads & Cross-App Tracking** | Zero Tracking | `NSPrivacyTracking = false`. No IDFA, no `AdSupport`, no AppTrackingTransparency. |
| **GPS Coordinates** | On-Device Only | Used solely on-device for solar calculations; never uploaded to our servers. |
| **Notifications** | 100% Local | Scheduled locally on your device; zero push notification token harvesting. |
| **Diagnostics & Analytics** | Anonymous | Firebase Crashlytics & Analytics (ad personalization disabled), never linked to identity. |

### 2. Location Permission & City Search

* **GPS Location (`NSLocationWhenInUseUsageDescription`):** Location permission is completely optional. When granted, your coordinates are used strictly on your device to calculate prayer times and reverse-geocode your city name and timezone via native OS services (`CLGeocoder` on iOS, `Geocoder` on Android). Exact GPS coordinates are never sent to our servers or Firebase, and background location tracking is never performed.
* **Manual City Search (Open-Meteo Geocoding API):** You may search any city worldwide without granting location permission. Manual search sends only the city query text and active language code to **Open-Meteo Geocoding API** (`geocoding-api.open-meteo.com`) without cookies or personal identifiers.

### 3. Local On-Device Storage (`UserDefaults` & App Group)

Your selected city, coordinates, timezone, calculation method, Asr madhab, language, and notification settings are stored strictly locally on your device. On iOS, shared preferences are stored in `UserDefaults` via App Group `group.com.okib.namaz` so the Home Screen Widget reflects your active city, as declared in `PrivacyInfo.xcprivacy` under `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1`).

### 4. Local Notifications

All prayer alerts are scheduled 100% locally on your device (`UNUserNotificationCenter` on iOS, `AlarmManager` / `WorkManager` on Android). Miqat does not operate remote push servers and does not harvest push notification tokens.

### 5. Anonymous Diagnostics & Aggregate Analytics

To improve stability and diagnose crashes, Miqat uses **Firebase Crashlytics** and **Firebase Analytics** (Google LLC):

* Ad personalization is disabled (`GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS = false`), IDFA is not collected, and cross-app tracking is disabled (`NSPrivacyTracking = false`).
* Only anonymous crash diagnostics (stack traces, OS version, device model) and non-identifying aggregate events (screen views, selected city/country name without GPS coordinates, calculation method, madhab, language, and notification toggle state) are recorded.
* Data is never linked to your identity, sold, or shared with advertising networks.

### 6. Data Retention, Deletion & Your Rights (GDPR & KVKK)

Local preferences are permanently removed when you uninstall the app or clear its storage. Anonymous Firebase diagnostic logs follow Google Firebase's standard retention period. Under GDPR (Articles 15–22) and KVKK (Article 11), you have the right to access, rectify, erase, or object to processing of your data.

### 7. Children's Privacy

Miqat is rated 4+ and safe for all ages. We do not knowingly collect personally identifiable information from children.

### 8. Contact

* **Developer / Data Controller:** Oktay İbiş
* **Email:** oktayibis@icloud.com

---

## 🇸🇦 العربية — سياسة الخصوصية

### 1. ملخص التزامنا بخصوصيتك

صُمم تطبيق **ميقات (Mîkât)** لاحترام خصوصيتك بالكامل. تتوافق هذه السياسة مع **إرشادات Apple App Store (البند 5.1.1)** واللائحة الأوروبية لحماية البيانات **(GDPR)** وقانون حماية البيانات الشخصية التركي **(KVKK)**.

* **لا توجد حسابات مستخدمين:** لا يتطلب التطبيق تسجيلاً أو بريداً إلكترونياً أو رقم هاتف.
* **صفر إعلانات وصفر تتبع:** (`NSPrivacyTracking = false`) لا يستخدم التطبيق معرف الإعلانات (IDFA) ولا يتتبعك عبر التطبيقات.
* **إحداثيات GPS على الجهاز فقط:** إذن الموقع (`NSLocationWhenInUseUsageDescription`) اختياري تماماً ويُستخدم على جهازك فقط لحساب المواقيت وتحديد اسم المدينة عبر خدمة النظام المحلية (`CLGeocoder` / `Geocoder`). لا تُرسل إحداثياتك الدقيقة لأي خادم.
* **البحث اليدوي عن المدينة:** يتم الاستعلام عبر **Open-Meteo Geocoding API** بإرسال اسم المدينة ورمز اللغة فقط دون أي معرفات شخصية.
* **التخزين المحلي:** تُحفظ تفضيلاتك محلياً على الجهاز (`UserDefaults` ضمن مجموعة التطبيقات `group.com.okib.namaz` على iOS المصرّح بها في `PrivacyInfo.xcprivacy` بالسبب `CA92.1`) لمشاركتها مع ودجت الشاشة الرئيسية.
* **إشعارات محلية 100%:** تُجدول التنبيهات محلياً بالكامل (`UNUserNotificationCenter` / `AlarmManager`) دون جمع رموز الإشعارات (Push Tokens).
* **التحليلات وتقارير الأعطال المجهولة:** يُستخدم **Firebase Crashlytics** و **Firebase Analytics** مع تعطيل إشارات تخصيص الإعلانات (`GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS = false`) لأغراض استقرار التطبيق فقط ودون ربطها بهويتك الشخصية.
* **التواصل:** أوقطاي إيبيش (Oktay İbiş) — `oktayibis@icloud.com`
