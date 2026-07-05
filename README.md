# Namaz Vakti (Prayer Times) App

Basit, reklamsız, temiz ve tamamen **çevrimdışı (offline-first)** çalışan yerel (native) Android ve iOS namaz vakti uygulaması.

---

## Proje Amacı & Temel Özellikler

1. **Çevrimdışı Çalışma (Offline-First)**: İlk kurulumda kullanıcının konumuna göre Aladhan API'den tüm yılın takvimini tek bir istekte indirir (`/v1/calendar/{year}`) ve cihazda önbelleğe alır. Yıl boyunca internet olmasa dahi takvimden çalışmaya devam eder. Önbelleğin eksik olduğu istisnai durumlarda, koordinatlara göre yerel matematiksel kütüphane hesaplamalarına otomatik geçiş yapar.
2. **Premium Onboarding (Kurulum Sihirbazı)**:
   * **Adım 1**: GPS ile mevcut konumu bulma veya metin kutusundan şehir arama (Open-Meteo Geocoding API).
   * **Adım 2**: Konumun ülkesine göre en uygun namaz hesaplama metodu ve mezhebi otomatik olarak seçilir (örn. Türkiye için Diyanet ve Hanefi mezhebi). Kullanıcı dilerse bunları değiştirebilir.
3. **Dahili Bildirim Sistemi (Local Notifications)**: Herhangi bir sunucu bağımlılığı olmadan, cihaz üzerinde çalışan bildirim motoru namaz vakitlerini ve öncesindeki hatırlatıcıları (varsayılan olarak 30 dk önce ve tam namaz vaktinde) planlar.
4. **Widget Desteği**: Hem Android hem de iOS platformlarında, ana ekranda bir sonraki namaz vaktini ve kalan süreyi gösteren yerel Widget desteği sunar.

---

## Mimari & Teknoloji Yığınları

Proje tamamen yerel diller ve modern arayüz kütüphaneleri kullanılarak geliştirilmiştir:

### Android Platformu
* **Dil & Arayüz**: Kotlin & Jetpack Compose (Material 3)
* **Veri Önbelleği**: JSON dosyası olarak `cacheDir` altında `namaz_cache_[locationId]_[year].json` olarak saklanır.
* **Hesaplama Motoru**: `com.batoulapps.adhan:adhan:1.2.1` (Çevrimdışı yedek hesaplamalar için).
* **Arka Plan İşleri**: Bildirimlerin taze kalması için `WorkManager` (24 saatlik periyotlarla `NotificationSyncWorker`).
* **Widget**: `AppWidgetProvider` tabanlı Jetpack Compose dışı geleneksel Android RemoteViews Widget'ı.

### iOS Platformu
* **Dil & Arayüz**: Swift & SwiftUI
* **Proje Yönetimi**: `xcodegen` ile yönetilir (`project.yml`). Xcode projesi doğrudan düzenlenmez, `xcodegen` ile üretilir.
* **Veri Önbelleği**: Ana uygulama ve Widget Kit extension'ın ortak okuyabilmesi için **App Group Suite** (`group.com.oktay.namaz`) altındaki `UserDefaults` içinde saklanır.
* **Hesaplama Motoru**: SPM (Swift Package Manager) üzerinden eklenen Batoulapps `Adhan-Swift` kütüphanesi.
* **Arka Plan İşleri**: `WidgetCenter.shared.reloadAllTimelines()` ve lokal bildirim planlama motoru.
* **Widget**: WidgetKit tabanlı, timeline sağlayıcılı modern SwiftUI Widget'ı.

---

## Geliştirici Notları & Komutlar

### Android Projesi Komutları (`/android` klasöründe)
* **Derleme**: `./gradlew assembleDebug`
* **Cihaza/Emülatöre Yükleme**: `./gradlew installDebug`
* **Çalıştırma**: `adb shell am start -n com.oktay.namaz/com.oktay.namaz.MainActivity`
* **Logcat Çökme Kontrolü**: `adb logcat -b crash -d`

### iOS Projesi Komutları (`/ios` klasöründe)
* **Proje Dosyalarını Yenileme (Zorunlu)**: `xcodegen` (Dosya ekleme/çıkarma sonrası mutlaka çalıştırılmalıdır).
* **Simülatör için Derleme**: `xcodebuild -project NamazVakti.xcodeproj -scheme NamazVakti -sdk iphonesimulator`
* **Simülatöre Yükleme**: `xcrun simctl install booted [DerivedData]/Products/Debug-iphonesimulator/NamazVakti.app`
* **Uygulamayı Simülatörde Başlatma**: `xcrun simctl launch booted com.oktay.NamazVakti`
