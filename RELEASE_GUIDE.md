# Namaz Vakti — Production Release & CI/CD Playbook (TR / EN)

Bu doküman, **Namaz Vakti** iOS (App Store / TestFlight) ve Android (Google Play Console) uygulamalarının sıfırdan canlıya (production) alınması, imzalanması ve yerel Mac üzerinden veya GitHub Actions aracılığıyla tam otomatik olarak dağıtılması için gereken tüm adımları **Türkçe** ve **İngilizce** olarak açıklar.

This playbook provides a complete, step-by-step **Turkish & English** production release guide for signing, archiving, and deploying **Namaz Vakti** to **Apple TestFlight / App Store** (iOS-first) and **Google Play Console** locally and via **GitHub Actions CI/CD**.

---

## 🚀 İLK ADIM: iOS TestFlight Hızlı Yayın (iOS-First Quickstart)

Uygulamayı **öncelikle iOS (TestFlight)** tarafında yayına almak için iki hızlı yöntem hazırlandı. Her iki yöntemde de **Xcode Automatic Provisioning (`-allowProvisioningUpdates`)** kullanılır; yani ana uygulama ve widget için ayrı ayrı `.mobileprovision` dosyası indirmenize **gerek yoktur**.

> **Bu Mac'teki Mevcut Durum (Local Keychain Tespiti):**
> - **Apple Team ID:** `3SN795A9D6` (`Oktay İbiş` — `ios/project.yml` içinde tanımlı)
> - **Xcode Sürümü:** `Xcode 27.2`
> - **Keychain Sertifikası:** `Apple Development: oktayibis@icloud.com (2ZG8A6RT9F)` mevcut. TestFlight arşivlemesi için aşağıda belirtildiği gibi Xcode üzerinden tek tıkla **Apple Distribution** sertifikası eklemeniz yeterlidir.

### Ön Hazırlık (Sadece 1 Kez — ~2 Dakika)
1. **Apple Distribution Sertifikası Ekleme:**
   - Bu Mac'te **Xcode → Settings (`⌘,`) → Accounts** sekmesini açın.
   - Apple ID'nizi (`oktayibis@icloud.com` / Team `3SN795A9D6`) seçip **Manage Certificates...** butonuna tıklayın.
   - Sol alttaki **`+`** butonuna basıp **Apple Distribution** seçin (sertifika otomatik olarak Keychain'inize eklenir).
2. **App Store Connect `.p8` API Anahtarı Alma:**
   - [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) sayfasına gidin.
   - **`+` (Generate API Key)** butonuna tıklayın → Adı: `NamazVakti Release`, Yetki: **`App Manager`** (veya `Admin`).
   - Sayfadaki **Issuer ID** (`APP_STORE_CONNECT_ISSUER_ID`), **Key ID** (`APP_STORE_CONNECT_API_KEY_ID`) değerlerini not edin ve `AuthKey_<KEY_ID>.p8` dosyasını indirin.
3. **App Store Connect'te Uygulama Kaydı:**
   - [App Store Connect → Apps](https://appstoreconnect.apple.com/apps) ekranında **`+` → New App** ile `com.okib.NamazVakti` Bundle ID'sine sahip uygulama kaydını oluşturun (Developer Portal'da `group.com.okib.namaz` App Group'unun hem `com.okib.NamazVakti` hem de `com.okib.NamazVakti.NamazVaktiWidget` için açık olduğundan emin olun).

---

### Yöntem 1: Bu Mac'ten Tek Komutla TestFlight'a Gönderim (`./scripts/ios-testflight.sh`)

GitHub Actions beklemeye gerek kalmadan doğrudan bu Mac üzerinden derleyip TestFlight'a yüklemek için:

1. `ios/.env.example` dosyasını `ios/.env` olarak kopyalayın (`ios/.env` git tarafından yoksayılır):
   ```bash
   cp ios/.env.example ios/.env
   ```
2. `ios/.env` dosyasını açıp 3 bilgiyi girin:
   ```dotenv
   APPLE_TEAM_ID=3SN795A9D6
   APP_STORE_CONNECT_API_KEY_ID=2X9R4HXF34
   APP_STORE_CONNECT_ISSUER_ID=69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   APP_STORE_CONNECT_API_KEY_PATH=~/Downloads/AuthKey_2X9R4HXF34.p8
   ```
3. Kök dizinden tek komutla arşivleyip TestFlight'a gönderin:
   ```bash
   # Varsayılan sürüm (1.0.0 / build 1) ile arşivle ve TestFlight'a yükle:
   ./scripts/ios-testflight.sh

   # Sürüm ve build numarasını belirterek TestFlight'a yükle:
   ./scripts/ios-testflight.sh --version 1.0.0 --build 2

   # TestFlight'a yüklemeden sadece imzalı .ipa üretmek için:
   ./scripts/ios-testflight.sh --archive-only
   ```

---

### Yöntem 2: GitHub Actions Pipeline ile Otomatik TestFlight Gönderimi (Sadece 6 Secret)

`.github/workflows/ios-testflight.yml` iş akışı **Automatic Provisioning** destekler. Manuel `.mobileprovision` secret'larına ihtiyaç duymadan **yalnızca şu 6 GitHub Secret** ile çalışır:

1. **Keychain'deki Apple Distribution Sertifikasını `.p12` Olarak Dışa Aktarın:**
   - **Keychain Access (Anahtar Zinciri Erişimi) → My Certificates** altından `Apple Distribution: ...` sertifikasına sağ tıklayıp **Export** seçin ve `Certificates.p12` olarak kaydedin (belirlediğiniz parola: `IOS_P12_PASSWORD`).
2. **GitHub → Settings → Secrets and variables → Actions** altına şu **6 secret**'ı ekleyin:

| # | GitHub Secret Adı | Değer / Terminalden Kopyalama Komutu |
| :-: | :--- | :--- |
| 1 | `APPLE_TEAM_ID` | `3SN795A9D6` |
| 2 | `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect Key ID (örn. `2X9R4HXF34`) |
| 3 | `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer UUID |
| 4 | `APP_STORE_CONNECT_API_KEY_BASE64` | `base64 -i AuthKey_XXXX.p8 \| tr -d '\n' \| pbcopy` |
| 5 | `IOS_BUILD_CERTIFICATE_BASE64` | `base64 -i Certificates.p12 \| tr -d '\n' \| pbcopy` |
| 6 | `IOS_P12_PASSWORD` | `.p12` dosyasını dışa aktarırken belirlediğiniz parola |

3. **Pipeline'ı Tetikleyin (Tag veya GitHub UI):**
   ```bash
   # v* veya ios-v* etiketi doğrudan iOS TestFlight pipeline'ını başlatır:
   git tag -a v1.0.0 -m "iOS Release v1.0.0"
   git push origin v1.0.0
   ```
   *(Veya GitHub → **Actions → iOS Release to TestFlight → Run workflow** butonuna basın.)*

> **Not (Android Pipeline Durumu):** Google Play geliştirici hesabı doğrulaması tamamlanana kadar `v1.0.0` etiketi yalnızca iOS pipeline'ını tetikler. Android pipeline'ı (`android-playstore.yml`) yalnızca `android-v*` etiketiyle veya manuel `workflow_dispatch` ile çalışır ve `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` henüz tanımlanmamış olsa bile hata vermeden `.aab` paketini derleyip GitHub Actions Artifact olarak kaydeder.

---

## İçindekiler / Table of Contents

1. [Mimari ve Kimlik Özeti / Identifiers & Architecture Summary](#1-mimari-ve-kimlik-özeti--identifiers--architecture-summary)
2. [Bölüm 1 (TR): Apple Developer & App Store Connect Kurulumu (iOS & TestFlight)](#2-bölüm-1-tr-apple-developer--app-store-connect-kurulumu-ios--testflight)
3. [Part 1 (EN): Apple Developer & App Store Connect Setup (iOS & TestFlight)](#3-part-1-en-apple-developer--app-store-connect-setup-ios--testflight)
4. [Bölüm 2 (TR): Google Play Console & Android İmzalama Kurulumu](#4-bölüm-2-tr-google-play-console--android-imzalama-kurulumu)
5. [Part 2 (EN): Google Play Console & Android Signing Setup](#5-part-2-en-google-play-console--android-signing-setup)
6. [Bölüm 3 / Part 3: GitHub Actions Secrets Referans Tablosu / Secrets Table](#6-bölüm-3--part-3-github-actions-secrets-referans-tablosu--secrets-table)
7. [Bölüm 4 / Part 4: Sürüm Tetikleme (Yerel & CI/CD) / Triggering Local & CI Releases](#7-bölüm-4--part-4-sürüm-tetikleme-yerel--cicd--triggering-local--ci-releases)

---

## 1. Mimari ve Kimlik Özeti / Identifiers & Architecture Summary

| Özellik / Property | iOS | Android |
| :--- | :--- | :--- |
| **Ana Uygulama Kimliği / App Bundle ID** | `com.okib.NamazVakti` | `com.oktay.namaz` |
| **Widget Kimliği / Widget Extension ID** | `com.okib.NamazVakti.NamazVaktiWidget` | *(Dahili / Built-in `PrayerAppWidget`)* |
| **App Group (Paylaşımlı Veri / Shared Storage)** | `group.com.okib.namaz` | *(Dahili `SharedPreferences` & `cacheDir`)* |
| **Apple Team ID** | `3SN795A9D6` | N/A |
| **Minimum / Hedef SDK (Min / Target SDK)** | iOS `16.0+` | `minSdk 26` / `targetSdk 35` |
| **CI/CD İş Akışları / Workflows** | `.github/workflows/ci.yml`<br>`.github/workflows/ios-testflight.yml` | `.github/workflows/ci.yml`<br>`.github/workflows/android-playstore.yml` |

---

## 2. Bölüm 1 (TR): Apple Developer & App Store Connect Kurulumu (iOS & TestFlight)

### 2.1. Apple Developer Portal: App Group ve App ID Tanımlamaları
iOS uygulaması ve ana ekran widget'ı (`NamazVaktiWidget`) vakit verilerini `group.com.okib.namaz` üzerinden paylaşır. Bu nedenle iki ayrı App ID ve bir App Group oluşturulmalıdır:

1. **App Group Oluşturma:**
   - [Apple Developer Portal → Identifiers](https://developer.apple.com/account/resources/identifiers/list) sayfasına gidin.
   - Sağ üstteki **+** butonuna tıklayın → **App Groups** seçin → **Continue**.
   - **Description**: `Namaz Vakti Shared Group`
   - **Identifier**: `group.com.okib.namaz`
   - **Continue** ve **Register** ile kaydedin.

2. **Ana Uygulama App ID (`com.okib.NamazVakti`):**
   - **Identifiers → + → App IDs → App** seçin.
   - **Bundle ID (Explicit)**: `com.okib.NamazVakti`
   - **Capabilities** listesinden şunları işaretleyin:
     - ✅ **App Groups** → **Configure** tıklayıp `group.com.okib.namaz` grubunu bağlayın.
     - ✅ **Time Sensitive Notifications** (`com.apple.developer.usernotifications.time-sensitive` — ezan bildirimlerinin Odak/Focus modunu aşabilmesi için zorunludur).
   - Kaydedin.

3. **Widget Extension App ID (`com.okib.NamazVakti.NamazVaktiWidget`):**
   - **Identifiers → + → App IDs → App** seçin.
   - **Bundle ID (Explicit)**: `com.okib.NamazVakti.NamazVaktiWidget`
   - **Capabilities** listesinden:
     - ✅ **App Groups** → **Configure** tıklayıp aynı `group.com.okib.namaz` grubunu seçin.
   - Kaydedin.

### 2.2. Dağıtım Sertifikası (Apple Distribution Certificate `.p12`)
1. **Xcode → Settings (`⌘,`) → Accounts → Manage Certificates → `+` → Apple Distribution** ile sertifikayı oluşturun (veya Keychain Access CSR yöntemiyle Apple Developer Portal'dan oluşturup indirin).
2. **Keychain Access → My Certificates** sekmesinde `Apple Distribution: ...` sertifikasını sağ tıklayıp **Export** seçin:
   - Dosya formatı: **Personal Information Exchange (.p12)** (`Certificates.p12`).
   - Güçlü bir parola belirleyin (bu parola **`IOS_P12_PASSWORD`** olacaktır).
3. `.p12` dosyasını Base64 formatına çevirip panoya kopyalayın (**`IOS_BUILD_CERTIFICATE_BASE64`**):
   ```bash
   base64 -i Certificates.p12 | tr -d '\n' | pbcopy
   ```

### 2.3. Provisioning Profiles (Otomatik vs. İsteğe Bağlı Manuel)
- **Otomatik Mod (Önerilen):** Hem `./scripts/ios-testflight.sh` hem de `.github/workflows/ios-testflight.yml`, `-allowProvisioningUpdates` ve App Store Connect `.p8` API anahtarını kullanarak `com.okib.NamazVakti` ve `com.okib.NamazVakti.NamazVaktiWidget` için gerekli profilleri **otomatik oluşturur ve imzalar**. Hiçbir `.mobileprovision` dosyası indirmenize gerek yoktur.
- **Manuel Mod (İsteğe Bağlı):** Eğer profilleri kendiniz yönetmek isterseniz [Apple Developer → Profiles](https://developer.apple.com/account/resources/profiles/list) altından iki adet **App Store Connect** profili oluşturup Base64 değerlerini `IOS_PROVISIONING_PROFILE_BASE64` ve `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` secret'larına ekleyebilirsiniz; iş akışı bu iki secret tanımlıysa otomatik olarak manuel moda geçer.

### 2.4. App Store Connect API Anahtarı (`.p8`)
CI/CD iş akışının ve `./scripts/ios-testflight.sh` betiğinin 2FA (iki aşamalı doğrulama) gerektirmeden TestFlight'a `.ipa` yükleyebilmesi için App Store Connect API anahtarı kullanılır:

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) sekmesine gidin.
2. **Generate API Key** (veya **+**) butonuna tıklayın:
   - **Name**: `GitHub Actions CI`
   - **Access**: `App Manager` (veya `Admin`)
3. Sayfanın üst kısmındaki **Issuer ID** değerini kopyalayın → **`APP_STORE_CONNECT_ISSUER_ID`**.
4. Oluşturulan anahtarın **Key ID** değerini kopyalayın (örn. `2X9R4HXF34`) → **`APP_STORE_CONNECT_API_KEY_ID`**.
5. **Download API Key** ile `AuthKey_<KEY_ID>.p8` dosyasını indirin (yalnızca bir kez indirilebilir!) ve Base64 değerini **`APP_STORE_CONNECT_API_KEY_BASE64`** için kopyalayın:
   ```bash
   base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy
   ```

### 2.5. App Store Gizlilik & Uyumluluk Kontrol Listesi
- **Privacy Manifest (`PrivacyInfo.xcprivacy`)**: `NSPrivacyAccessedAPICategoryUserDefaults` kategorisi `CA92.1` (uygulama ve widget arası App Group veri paylaşımı) gerekçesiyle tanımlanmıştır.
- **Sıfır Takip / Zero IDFA**: `AdSupport` veya `AppTrackingTransparency` bağlanmamıştır (`NSPrivacyTracking = false`). App Store Connect *App Privacy* formunda **"No, we do not track users"** seçilmelidir.
- **Şifreleme Beyanı (`Info.plist`)**: `ITSAppUsesNonExemptEncryption = false` tanımlıdır; TestFlight yüklemelerinde her seferinde ihracat uyumluluğu onayı sormaz.
- **Firebase API Key Kısıtlaması**: Google Cloud Console → *APIs & Services → Credentials* altından `GoogleService-Info.plist` içindeki API anahtarını yalnızca `com.okib.NamazVakti` Bundle ID'si ile sınırlandırın.

---

## 3. Part 1 (EN): Apple Developer & App Store Connect Setup (iOS & TestFlight)

### 3.1. Apple Developer Portal: App Group & Explicit App IDs
Because the main app and WidgetKit extension share cached prayer timetables and user preferences via `UserDefaults(suiteName: "group.com.okib.namaz")`, register the App Group and two explicit App IDs:

1. **Register the App Group:**
   - Go to [Apple Developer Portal → Identifiers](https://developer.apple.com/account/resources/identifiers/list) → click **+** → select **App Groups**.
   - Set Identifier to `group.com.okib.namaz` and register.
2. **Main App Identifier (`com.okib.NamazVakti`):**
   - Enable **App Groups** (select `group.com.okib.namaz`) and **Time Sensitive Notifications** (`com.apple.developer.usernotifications.time-sensitive`).
3. **Widget Extension Identifier (`com.okib.NamazVakti.NamazVaktiWidget`):**
   - Enable **App Groups** and attach the same `group.com.okib.namaz` container.

### 3.2. Apple Distribution Certificate (`.p12`) & Automatic Provisioning
1. Create an **Apple Distribution** certificate in Xcode (**Settings → Accounts → Manage Certificates → + → Apple Distribution**), then export the certificate + private key from Keychain Access as `Certificates.p12` protected by password **`IOS_P12_PASSWORD`**.
2. Base64-encode the `.p12` into **`IOS_BUILD_CERTIFICATE_BASE64`**:
   ```bash
   base64 -i Certificates.p12 | tr -d '\n' | pbcopy
   ```
3. **Automatic Provisioning (Default):** Both `./scripts/ios-testflight.sh` and `.github/workflows/ios-testflight.yml` pass `-allowProvisioningUpdates` with your App Store Connect API Key so Xcode automatically manages provisioning profiles for `com.okib.NamazVakti` and `com.okib.NamazVakti.NamazVaktiWidget`. Manual profile secrets (`IOS_PROVISIONING_PROFILE_BASE64` and `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`) are completely optional.

### 3.3. App Store Connect API Key (`.p8`)
1. Open [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Create an API key with **App Manager** (or **Admin**) access.
3. Save **Key ID** (`APP_STORE_CONNECT_API_KEY_ID`), **Issuer ID** (`APP_STORE_CONNECT_ISSUER_ID`), and base64-encode the downloaded `.p8` file into `APP_STORE_CONNECT_API_KEY_BASE64`:
   ```bash
   base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy
   ```

---

## 4. Bölüm 2 (TR): Google Play Console & Android İmzalama Kurulumu

*(Google Play geliştirici hesabı doğrulaması tamamlandığında aşağıdaki adımlarla Android tarafı da tek komutla devreye alınabilir.)*

### 4.1. Upload Keystore (`upload-keystore.jks`) Oluşturma
Android release paketlerini (`.aab` / `.apk`) imzalamak için `keytool` ile bir Upload Keystore üretin:

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

- Komutun sorduğu Keystore parolasını **`ANDROID_KEYSTORE_PASSWORD`**, key parolasını **`ANDROID_KEY_PASSWORD`** ve alias değerini (`upload`) **`ANDROID_KEY_ALIAS`** olarak kaydedin.
- Keystore dosyasını GitHub Secrets için Base64 formatına dönüştürün (**`ANDROID_KEYSTORE_BASE64`**):
  ```bash
  base64 -i upload-keystore.jks | tr -d '\n' | pbcopy
  ```
- **ÖNEMLİ:** `upload-keystore.jks` dosyasını asla Git deposuna commit etmeyin; güvenli bir parola yöneticisinde yedekleyin.

### 4.2. Yerel İmzalama (`keystore.properties` veya Ortam Değişkenleri)
`/android/app/build.gradle.kts` dosyası imzalama bilgilerini şu iki yöntemden biriyle otomatik okur:
1. **Ortam Değişkenleri (CI/CD ve Terminal için):**
   - `ANDROID_KEYSTORE_PATH`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
2. **Yerel `android/keystore.properties` Dosyası (Git tarafından yoksayılır):**
   ```properties
   storeFile=/tam/yol/upload-keystore.jks
   storePassword=KEYSTORE_PAROLANIZ
   keyAlias=upload
   keyPassword=KEY_PAROLANIZ
   ```

### 4.3. Google Play Console & İlk Manuel AAB Yükleme Zorunluluğu
> **KRİTİK KURAL (İlk Yükleme):** Google Play Developer API, henüz hiç paket yüklenmemiş taslak bir uygulama için otomatik sürüm oluşturamaz (`Package not found` hatası verir). Bu nedenle **ilk `.aab` dosyasını bir defaya mahsus Google Play Console web arayüzünden manuel olarak yüklemeniz zorunludur.**

1. [Google Play Console](https://play.google.com/console) üzerinde **Create app** butonuna tıklayın (`Namaz Vakti`, Varsayılan dil: `tr-TR` veya `en-US`, Uygulama, Ücretsiz).
2. **Setup → App integrity → Play App Signing** bölümünden Google tarafından yönetilen **Play App Signing**'i etkinleştirin.
3. Yerelde imzalı `.aab` dosyasını oluşturun:
   ```bash
   cd android
   ANDROID_KEYSTORE_PATH=/yol/upload-keystore.jks \
   ANDROID_KEYSTORE_PASSWORD="..." \
   ANDROID_KEY_ALIAS="upload" \
   ANDROID_KEY_PASSWORD="..." \
   ./gradlew bundleRelease
   ```
4. Oluşan `android/app/build/outputs/bundle/release/app-release.aab` dosyasını Google Play Console → **Testing → Internal testing → Create new release** ekranından manuel olarak yükleyip kaydedin.
5. Bu ilk manuel yüklemeden sonra tüm sonraki sürümler `.github/workflows/android-playstore.yml` tarafından tam otomatik olarak yayınlanabilir.

### 4.4. Google Cloud Service Account JSON (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`)
GitHub Actions'ın Google Play Console'a `.aab` yükleyebilmesi için bir Service Account oluşturulmalıdır:

1. [Google Cloud Console](https://console.cloud.google.com/) üzerinde bir proje seçin veya oluşturun.
2. **APIs & Services → Library** altından **Google Play Android Developer API**'yi aratıp **Enable** edin.
3. **IAM & Admin → Service Accounts → + Create Service Account** adımlarını izleyin:
   - **Service account name**: `github-actions-play-publisher`
   - Oluşturulan servis hesabına tıklayın → **Keys** sekmesi → **Add Key → Create new key → JSON** seçip `.json` dosyasını indirin.
   - Bu `.json` dosyasının tüm içeriğini **`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`** GitHub Secret'ına yapıştırın.
4. **Google Play Console'da Yetkilendirme:**
   - [Google Play Console → Users and permissions](https://play.google.com/console/users-and-permissions) sayfasına gidin.
   - **Invite new users** butonuna tıklayın ve Service Account'un e-posta adresini (`github-actions-play-publisher@<proje-id>.iam.gserviceaccount.com`) girin.
   - **App permissions** sekmesinden `Namaz Vakti` uygulamasını ekleyin ve şu yetkileri verin:
     - ✅ *View app information and download bulk reports (read-only)*
     - ✅ *Release to production, exclude devices, and use Play App Signing*
     - ✅ *Release apps to testing tracks*
     - ✅ *Manage testing tracks and edit tester lists*
   - **Invite user** ile kaydedin.

### 4.5. Google Play Kanal Yapısı (Tracks) ve Politika Beyanları
- **`internal` (Internal Testing / Dahili Test):** Saniyeler içinde yayına girer, Google incelemesi beklemez. CI/CD için varsayılan kanaldır.
- **`alpha` (Closed Testing / Kapalı Test):** Belirli test gruplarıyla paylaşılır.
- **`beta` (Open Testing / Açık Test):** Herkese açık erken erişim kanalıdır.
- **`production` (Production / Canlı):** Tüm kullanıcılara açılan canlı sürümdür.
- **Exact Alarm (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`) Beyanı:** Google Play Console *App content* bölümünde tam zamanlı alarm izni gerekçesi sorulduğunda uygulamanın temel işlevinin **"İslami namaz vakitleri ve ezan saatlerinde tam dakikasında yerel bildirim/alarm çalmak (core calendar/alarm clock functionality)"** olduğunu belirtin.

---

## 5. Part 2 (EN): Google Play Console & Android Signing Setup

### 5.1. Generating the Upload Keystore
Run `keytool` to generate your release upload keystore:
```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```
Encode the binary keystore as a single-line base64 string for the **`ANDROID_KEYSTORE_BASE64`** GitHub Secret:
```bash
base64 -i upload-keystore.jks | tr -d '\n' | pbcopy
```

### 5.2. First Manual AAB Upload & Play App Signing
1. Create the app in **Google Play Console** with package name `com.oktay.namaz` and enable **Play App Signing**.
2. **First Manual Upload Requirement:** Upload your first signed `app-release.aab` manually via **Testing → Internal testing** in the Google Play Console web UI. Once the package name is registered by that initial upload, GitHub Actions (`r0adkll/upload-google-play@v1`) can deploy all subsequent builds automatically to `internal`, `alpha`, `beta`, or `production`.

### 5.3. Google Cloud Service Account Setup
1. Enable the **Google Play Android Developer API** in Google Cloud Console.
2. Create a Service Account under **IAM & Admin → Service Accounts**, create a **JSON** key, and store the entire JSON payload in **`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`**.
3. Invite the Service Account email in **Google Play Console → Users and permissions**, attach the `Namaz Vakti` app, and grant release permissions for testing and production tracks.

---

## 6. Bölüm 3 / Part 3: GitHub Actions Secrets Referans Tablosu / Secrets Table

GitHub deponuzda **Settings → Secrets and variables → Actions → New repository secret** menüsünden aşağıdaki secret'ları tanımlayın (iOS TestFlight yayını için ilk 6 secret yeterlidir):

| Secret Adı / Name | Platform | Zorunluluk | Açıklama / Description | Üretim Komutu / Example Command or Value |
| :--- | :---: | :---: | :--- | :--- |
| `APPLE_TEAM_ID` | iOS | **Zorunlu** | 10 haneli Apple Developer Team ID | `3SN795A9D6` |
| `APP_STORE_CONNECT_API_KEY_ID` | iOS | **Zorunlu** | App Store Connect API Key ID | `2X9R4HXF34` |
| `APP_STORE_CONNECT_ISSUER_ID` | iOS | **Zorunlu** | App Store Connect API Issuer UUID | `69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | iOS | **Zorunlu** | `.p8` API anahtarının Base64 hali | `base64 -i AuthKey_XXXX.p8 \| tr -d '\n'` |
| `IOS_BUILD_CERTIFICATE_BASE64` | iOS | **Zorunlu** | Apple Distribution `.p12` sertifikasının Base64 hali | `base64 -i Certificates.p12 \| tr -d '\n'` |
| `IOS_P12_PASSWORD` | iOS | **Zorunlu** | `.p12` dışa aktarma parolası | `Guc1uParola!` |
| `IOS_PROVISIONING_PROFILE_BASE64` | iOS | *İsteğe Bağlı* | Manuel imzalama istenirse ana uygulama `.mobileprovision` Base64 hali | `base64 -i NamazVakti_AppStore.mobileprovision \| tr -d '\n'` |
| `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` | iOS | *İsteğe Bağlı* | Manuel imzalama istenirse widget `.mobileprovision` Base64 hali | `base64 -i NamazVaktiWidget_AppStore.mobileprovision \| tr -d '\n'` |
| `ANDROID_KEYSTORE_BASE64` | Android | Hesap Açılınca | `upload-keystore.jks` dosyasının Base64 hali | `base64 -i upload-keystore.jks \| tr -d '\n'` |
| `ANDROID_KEYSTORE_PASSWORD` | Android | Hesap Açılınca | Keystore (`storePassword`) parolası | `KeystoreParolaniz` |
| `ANDROID_KEY_ALIAS` | Android | Hesap Açılınca | Keystore içindeki anahtar takma adı (`keyAlias`) | `upload` |
| `ANDROID_KEY_PASSWORD` | Android | Hesap Açılınca | Anahtar (`keyPassword`) parolası | `KeyParolaniz` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Android | Hesap Açılınca | Google Cloud Service Account JSON dosyasının tam metni | `{ "type": "service_account", "project_id": "..." }` |

---

## 7. Bölüm 4 / Part 4: Sürüm Tetikleme (Yerel & CI/CD) / Triggering Local & CI Releases

### 7.1. Sürüm Öncesi Yerel Doğrulama / Local Pre-Flight Check (`scripts/release-check.sh`)
Yeni bir etiket (tag) oluşturmadan önce her iki platformun derlendiğini, birim testlerinin geçtiğini ve sürüm dosyalarının eksiksiz olduğunu doğrulamak için kök dizinde şu komutu çalıştırın:

```bash
# Tam doğrulama (Dosyalar + Android Test/Debug/Release + iOS XcodeGen/Simulator Build/Test)
./scripts/release-check.sh

# Yalnızca dosya ve yapılandırma kontrolü / Files & config check only
./scripts/release-check.sh --files-only

# Yalnızca iOS veya yalnızca Android kontrolü
./scripts/release-check.sh --ios-only
./scripts/release-check.sh --android-only
```

### 7.2. Git Tag ile Otomatik CI/CD Sürümü / Tag-Based Automated Releases
- **iOS (TestFlight) Yayınlama (`v*` veya `ios-v*`):**
  ```bash
  git tag -a v1.0.0 -m "Release v1.0.0"
  git push origin v1.0.0
  # veya
  git tag -a ios-v1.0.0 -m "iOS Release v1.0.0"
  git push origin ios-v1.0.0
  ```
- **Android (Google Play) Yayınlama (`android-v*`):**
  ```bash
  git tag -a android-v1.0.0 -m "Android Release v1.0.0"
  git push origin android-v1.0.0
  ```

### 7.3. GitHub Actions Arayüzünden Manuel Tetikleme (`workflow_dispatch`)
1. **iOS Release to TestFlight (`.github/workflows/ios-testflight.yml`):**
   - GitHub → **Actions → iOS Release to TestFlight → Run workflow** butonuna tıklayın.
   - İsteğe bağlı olarak `version` (örn. `1.0.0`), `build_number` (boş bırakılırsa `github.run_number` kullanılır) ve `upload_to_testflight` (`true`/`false`) parametrelerini seçip çalıştırın.
2. **Android Release to Google Play (`.github/workflows/android-playstore.yml`):**
   - GitHub → **Actions → Android Release to Google Play → Run workflow** butonuna tıklayın.
   - Hedef kanalı (`track`: `internal`, `alpha`, `beta`, `production`) ve sürüm durumunu (`release_status`: `completed` veya `draft`) seçip çalıştırın. (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` henüz girilmemişse `.aab` dosyası derlenip Actions Artifact olarak indirilebilir hale getirilir ve Google Play yükleme adımı hata vermeden atlanır.)

### 7.4. Yerel Terminal Üzerinden Manuel Derleme & Dağıtım / Local CLI Builds

#### iOS (Tek Komutla Yerel Archive, Otomatik İmzalama & TestFlight Yükleme)
```bash
# ios/.env dosyası veya ortam değişkenleri ile:
./scripts/ios-testflight.sh --version 1.0.0 --build 1
```

#### Android (Yerel İmzalı `.aab` Üretimi)
```bash
cd android
ANDROID_KEYSTORE_PATH="$HOME/keystores/upload-keystore.jks" \
ANDROID_KEYSTORE_PASSWORD="***" \
ANDROID_KEY_ALIAS="upload" \
ANDROID_KEY_PASSWORD="***" \
./gradlew bundleRelease
# Çıktı / Output: android/app/build/outputs/bundle/release/app-release.aab
```
