# iOS App Store Review — Yayın Öncesi Kontrol Listesi (Mîkât `v1.0`)

**Uygulama:** Mîkât (`com.okib.NamazVakti`)  
**App Store Connect App ID:** `6837418994`  
**Build:** `1.0.0 (1)` — Durum: `VALID` (`APP_STORE_ELIGIBLE`, `usesNonExemptEncryption: false`)  
**Son Denetim Tarihi:** 20 Kasım 2026

---

## 1. App Store Connect Canlı API Durumu (Otomatik Doldurulan vs. Kalan Alanlar)

| Alan | Durum | Değer / Yapılması Gereken |
| :--- | :---: | :--- |
| **Build `1.0.0 (1)` İşleme** | ✅ Tamamlandı | `processingState: VALID`, sürüm `1.0` ile **otomatik bağlandı**. |
| **İçerik Hakları (Content Rights)** | ✅ Tamamlandı | `DOES_NOT_USE_THIRD_PARTY_CONTENT` olarak ayarlandı. |
| **Kategoriler** | ✅ Tamamlandı | Birincil: **Reference (Başvuru)**, İkincil: **Lifestyle (Yaşam Tarzı)**. |
| **Yaş Derecelendirmesi (Age Rating)** | ✅ Tamamlandı | Tüm içerik beyanları `NONE` / `false` → **4+** (`FOUR_PLUS`) onaylandı. |
| **Telif Hakkı (Copyright)** | ✅ Tamamlandı | `2026 Oktay İbiş` |
| **Uygulama Adı & Alt Başlık (`tr`, `en-US`, `ar-SA`)** | ✅ Mevcut | Kullanıcı tarafından ayarlanan `Mîkât` ve yerelleştirilmiş alt başlıklar korundu. |
| **Açıklama, Anahtar Kelimeler, Tanıtım Metni (`tr`, `en-US`, `ar-SA`)** | ✅ Tamamlandı | `APP_STORE_METADATA.md` içeriğiyle 3 dilde otomatik dolduruldu. |
| **Gizlilik Politikası URL'leri (`tr`, `en-US`, `ar-SA`)** | ✅ Ayarlandı* | `https://oktayibis.github.io/namaz-vakti-native/privacy.html?lang=tr\|en\|ar` |
| **Destek & Pazarlama URL'leri (`tr`, `en-US`, `ar-SA`)** | ✅ Ayarlandı* | `support.html?lang=...` ve `/?lang=...` |
| **Export Compliance (`ITSAppUsesNonExemptEncryption`)** | ✅ Tamamlandı | `Info.plist` içinde `false`, build üzerinde `usesNonExemptEncryption: false` algılandı. |
| **GitHub Pages Yayına Alma** | ⏳ **Gerekli** | Repo push edildikten sonra GitHub Settings → Pages üzerinden `/docs` aktif edilmeli (bkz. Bölüm 2). |
| **App Review İletişim Bilgisi & Notlar** | ⏳ **Gerekli** | Apple API telefon numarasını (`+90 ...`) zorunlu tuttuğu için ASC panelinden girilmeli (bkz. Bölüm 3). |
| **Fiyatlandırma ve Kullanılabilirlik (Pricing & Availability)** | ⏳ **Gerekli** | API'de henüz tanımlı değil (`404`). ASC → **Monetization → Pricing and Availability** altında **Free ($0)** ve ülke/bölge seçimi kaydedilmeli (AB DSA trader beyanı dahil). |
| **App Privacy (Uygulama Gizliliği Etiketleri)** | ⏳ **Gerekli** | ASC → **App Privacy** anketi doldurulup **Publish** edilmeli (bkz. Bölüm 4). |
| **Ekran Görüntüleri (Screenshots)** | ⏳ **Gerekli** | 3 dil (`tr`, `en-US`, `ar-SA`) için şu an `0` ekran görüntüsü var (bkz. Bölüm 5). |

*\*Not: URL'ler App Store Connect'e kaydedildi; incelemeye göndermeden önce GitHub Pages'i aktifleştirip her URL'nin HTTP 200 döndüğünü doğrulayın.*

---

## 2. GitHub Pages Aktivasyon Adımları (Gizlilik & Destek Sayfalarını Canlıya Alma)

Tüm yasal ve destek sayfaları `/docs` klasöründe sıfır derleme gereksinimiyle (🇹🇷 TR / 🇬🇧 EN / 🇸🇦 AR dil değiştiricili) oluşturuldu:
- `docs/index.html` (Tanıtım / Marketing URL)
- `docs/privacy.html` (Gizlilik Politikası — Apple 5.1.1, GDPR & KVKK uyumlu)
- `docs/support.html` (Destek ve SSS — Apple Support URL gereksinimi)
- `docs/terms.html` (Kullanım Koşulları)
- `docs/.nojekyll`

**Aktifleştirme:**
1. Değişiklikleri `main` dalına commit & push edin:
   ```bash
   git add docs/ PRIVACY_POLICY.md APP_STORE_REVIEW_CHECKLIST.md
   git commit -m "docs: add GitHub Pages legal/support site and App Store checklist"
   git push origin main
   ```
2. GitHub üzerinde **[oktayibis/namaz-vakti-native → Settings → Pages](https://github.com/oktayibis/namaz-vakti-native/settings/pages)** sayfasını açın.
3. **Build and deployment → Source:** `Deploy from a branch` seçin.
4. **Branch:** `main` ve klasör olarak **`/docs`** seçip **Save** tıklayın.
5. 1–2 dakika içinde şu URL'lerin açıldığını (HTTP 200) doğrulayın:
   - https://oktayibis.github.io/namaz-vakti-native/
   - https://oktayibis.github.io/namaz-vakti-native/privacy.html?lang=tr
   - https://oktayibis.github.io/namaz-vakti-native/privacy.html?lang=en
   - https://oktayibis.github.io/namaz-vakti-native/privacy.html?lang=ar
   - https://oktayibis.github.io/namaz-vakti-native/support.html?lang=tr

---

## 3. App Review Information (İnceleme Bilgileri — Kopyala & Yapıştır)

App Store Connect → **App Store → iOS 1.0 → App Review Information** bölümüne gidin:

- **Sign-in required:** ❌ İşaretini kaldırın (`false`)
- **First Name:** `Oktay`
- **Last Name:** `İbiş`
- **Phone Number:** `+90 ...` *(Uluslararası `+` ülke koduyla geçerli telefon numaranızı girin)*
- **Email:** `oktayibis@icloud.com`
- **Notes (İngilizce — doğrudan kopyalayıp yapıştırın):**

```text
Thank you for reviewing Mîkât (Miqat).

- No login or account is required.
- How to test onboarding & prayer times: On first launch, tap "Use Current Location" (GPS) or tap the search bar to search any city worldwide (e.g., "Istanbul", "London", "Makkah", or "New York"). Location permission is completely optional; manual city search works without granting location access.
- Offline calculation: Once a city is selected, all 6 daily prayer times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha), Hijri date, and the circular countdown ring are computed 100% on-device using astronomical algorithms.
- Desk Clock / StandBy mode: Rotate an iPhone to landscape on the Home screen to inspect the 3-column Desk Clock layout.
- Notifications: Prayer reminders are scheduled locally via UNUserNotificationCenter using Time-Sensitive interruption level so worship alerts can break through Focus mode when permitted by the user.
- Home Screen Widgets: Small and Medium WidgetKit extensions are included and share the active city via App Group (group.com.okib.namaz).
```

---

## 4. App Privacy (Gizlilik Etiketleri) — Doğru Anket Yanıtları

App Store Connect → **Trust & Safety → App Privacy → Get Started**:

> ⚠️ **Önemli:** Uygulamada **Firebase Analytics** ve **Firebase Crashlytics** (`AnalyticsService.swift`) etkin olduğu için Apple incelemesinde tutarsızlık (Guideline 5.1.1 / Privacy Nutrition Label mismatch) yaşanmaması adına **"Yes, we collect data from this app"** seçip yalnızca aşağıdaki **anonim / kimlikle ilişkilendirilmeyen** 3 veri tipini beyan edin:

1. **Diagnostics → Crash Data**
   - Purpose: **App Functionality** ve **Analytics**
   - Linked to the user's identity? → **No**
   - Used for tracking purposes? → **No**
2. **Usage Data → Product Interaction**
   - Purpose: **Analytics**
   - Linked to the user's identity? → **No**
   - Used for tracking purposes? → **No**
3. **Location → Coarse Location** *(yalnızca seçilen şehir/ülke adı Firebase Analytics & Crashlytics olay parametresi olarak kaydedildiği için; kesin GPS koordinatları asla gönderilmez)*
   - Purpose: **Analytics** ve **App Functionality**
   - Linked to the user's identity? → **No**
   - Used for tracking purposes? → **No**

Son adımda **Publish** düğmesine tıklayın. *(Not: `PrivacyInfo.xcprivacy` dosyası hem ana uygulamada hem widget hedefinde `NSPrivacyTracking = false` ve `CA92.1` beyanıyla hazırdır.)*

---

## 5. Ekran Görüntüsü Gereksinimleri & Önemli Cihaz Ailesi Uyarısı (`TARGETED_DEVICE_FAMILY`)

> 🚨 **KRİTİK BULGU (`ios/project.yml` / `project.pbxproj`):**  
> Mevcut Build `1.0.0 (1)` **`TARGETED_DEVICE_FAMILY = "1,2"`** (hem iPhone hem iPad) ile derlenmiştir. Bu nedenle App Store Connect incelemeye gönderirken **iPad ekran görüntüsü de zorunlu tutacaktır!**
>
> **İki seçeneğiniz var:**
> - **Seçenek A (Hızlı — Mevcut Build `1.0.0 (1)` ile):** Hem **iPhone 6.9"** hem **iPad 13"** ekran görüntülerini yükleyin (ve iPad simülatöründe arayüzü hızlıca kontrol edin).
> - **Seçenek B (Sadece iPhone uygulaması olacaksa):** `ios/project.yml` içinde `NamazVakti` ve `NamazVaktiWidget` hedeflerine `TARGETED_DEVICE_FAMILY: "1"` ekleyip `xcodegen` çalıştırın, `CURRENT_PROJECT_VERSION: 2` ile yeni build yükleyin. Böylece yalnızca iPhone ekran görüntüleri yeterli olur.
> - **Mac (Apple Silicon) & Apple Vision Pro:** Build üzerinde `computedMinMacOsVersion: 13.0` ve `computedMinVisionOsVersion: 1.0` görünüyor. Eğer macOS/visionOS mağazalarında görünmesini istemiyorsanız **Pricing and Availability → iPhone and iPad Apps on Apple Silicon Macs** onay kutusunu kaldırabilirsiniz.

### Zorunlu Ekran Görüntüsü Boyutları (PNG / JPEG, alpha kanalsız)

| Cihaz Boyutu | Önerilen Çözünürlük (Dikey) | Durum |
| :--- | :--- | :--- |
| **iPhone 6.9" Display** *(iPhone 16 Pro Max / 15 Pro Max)* | `1320 × 2868 px` veya `1290 × 2796 px` | **Zorunlu** (en az 1, önerilen 5–6 adet) |
| **iPad 13" Display** *(iPad Pro 13-inch M4)* | `2064 × 2752 px` veya `2048 × 2732 px` | **`TARGETED_DEVICE_FAMILY = "1,2"` olduğu sürece Zorunlu** |

*(Not: Apple'ın Media Manager özelliği sayesinde `tr`, `en-US` ve `ar-SA` dilleri için yerelleştirilmiş ekran görüntüleri yükleyebilir veya birincil dil `tr` üzerinden diğer dillere devraldırabilirsiniz; ancak her dilin kendi arayüzüyle çekilmiş ekran görüntüsü dönüşüm oranını belirgin biçimde artırır.)*

### Önerilen 5 Ekran Görüntüsü Senaryosu
1. **Ana Ekran (Dinamik Gökyüzü + Geri Sayım Halkası + Günlük Vakitler)**
2. **Masa Saati / StandBy Modu (Yatay 3 Sütunlu Görünüm)**
3. **Ana Ekran Widget'ları (Small & Medium Widget Görünümü)**
4. **Bildirim Ayarları (Zaman Duyarlı Hatırlatıcılar — 5–60 dk öncesi)**
5. **Hesaplama Metodları & Şehir Arama (Diyanet, MWL, Ümmü'l-Kurâ, %100 Çevrimdışı)**

---

## 6. Fiyatlandırma, Kullanılabilirlik & AB DSA Uyumu

App Store Connect → **Monetization → Pricing and Availability**:
- [ ] **Price Schedule:** `0.00 (Free)` seçip kaydedin.
- [ ] **Availability:** `All 175 countries or regions` (veya istediğiniz ülkeler) seçip kaydedin.
- [ ] **Digital Services Act (EU DSA):** AB mağazalarında dağıtım için **Compliance → Digital Services Act** bölümünde bireysel geliştirici (Non-Trader veya Trader) beyanınızı tamamlayın.

---

## 7. Gönderim Öncesi Son Kontrol

- [ ] TestFlight'ta gerçek iPhone üzerinde Build `1.0.0 (1)` kuruldu ve uçtan uca test edildi (Onboarding, GPS & manuel arama, geri sayım, yatay StandBy modu, yerel bildirim, Ana Ekran Widget'ı).
- [ ] GitHub Pages aktif ve `privacy.html`, `support.html`, `index.html` canlıda 200 OK dönüyor.
- [ ] App Privacy etiketleri yayınlandı (`Published`).
- [ ] Pricing (`Free`) & Availability kaydedildi.
- [ ] App Review Information (telefon numarası + inceleme notları) kaydedildi.
- [ ] Ekran görüntüleri yüklendi.
- [ ] **Add for Review → Submit to App Review** tıklandı!
