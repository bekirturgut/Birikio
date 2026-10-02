<p align="center">
  <img src="docs/images/birikio-banner.svg" alt="Birikio — Biriktir. Büyüt. Hayaline ulaş." width="100%" />
</p>

<p align="center">
  <strong>Gelirini tanı. Harcamalarını gör. Hayaline yer aç.</strong><br />
  Türkçe, animasyonlu ve internet bağlantısı gerektirmeyen kişisel finans uygulaması.
</p>

<p align="center">
  <a href="#ekran-görüntüleri">Ekran görüntüleri</a> ·
  <a href="#özellikler">Özellikler</a> ·
  <a href="#kurulum">Kurulum</a> ·
  <a href="#veriler-ve-hesaplama">Veriler ve hesaplama</a> ·
  <a href="#geliştirme">Geliştirme</a>
</p>

---

Birikio, günlük para takibini birikim hedeflerinle bir araya getirir. İster ilk motorun, ister bir tatil, ister bir güvence birikimi: hedefini seç, para ayır ve ilerlemeni gör. Hesap oluşturman gerekmez; kayıtların cihazında tutulur.

## Ekran görüntüleri

Görseller uygulamanın güncel Flutter arayüzünden, cihazda saklanmayan kurgu örnek verilerle üretildi. Tutarlar ve tarihler yalnızca anlatım içindir.

### 1. Bir bakışta durumun

Anasayfada kullanılabilir bakiyeyi, bu ayın gelir ve giderini ve birikim hedefinin ilerlemesini birlikte görürsün. Açık ve koyu tema aynı verileri gösterir.

<table>
  <tr>
    <td align="center"><strong>Koyu tema</strong><br /><sub>Bakiye, aylık özet ve hedef ilerlemesi.</sub><br /><br /><img src="docs/images/home-dark.png" alt="Koyu temada ana ekran, kullanılabilir bakiye ve birikim hedefi" width="310" /></td>
    <td align="center"><strong>Açık tema</strong><br /><sub>Aynı finansal görünüm açık renkte.</sub><br /><br /><img src="docs/images/home-light.png" alt="Açık temada ana ekran ve finansal özet" width="310" /></td>
  </tr>
</table>

### 2. Gelir ve giderlerini kaydet

Alttaki **+** düğmesi gelir, gider ve birikim hedefi ekleme akışlarını açar. Gelir & Gider ekranında **Kayıtlar / Yıllık radar / Düzenli** görünümlerine doğrudan geçersin. Kayıtlarda oklarla ay değiştirir veya **Tüm kayıtları göster** ile bütün geçmişi açarsın. Düzenli görünümü bütün serileri listeler. Yeni kayıt eklenince kaydın ayı açılır ve önceki arama/filtreler temizlenir. Kategori, tarih, tutar ve tekrar durumuyla ayrıca filtreleyebilirsin. Tutar yazarken binlik gruplar otomatik noktayla ayrılır.

<table>
  <tr>
    <td align="center"><strong>Hızlı ekleme</strong><br /><sub>Her ekrandan yeni kayıt oluştur.</sub><br /><br /><img src="docs/images/add-menu.png" alt="Gelir, gider ve birikim hedefi ekleme menüsü" width="310" /></td>
    <td align="center"><strong>Gelir & Gider</strong><br /><sub>Gerçekleşmiş işlemler ve düzenli ödemeler.</sub><br /><br /><img src="docs/images/transactions.png" alt="Gelir ve gider özeti ile düzenli ödemeler listesi" width="310" /></td>
  </tr>
</table>

### 3. İleri tarihli gideri veya düzenli ödemeyi planla

Gider formunda ileri tarih seçersen tek seferlik kayıt **bekleyen ödeme** olur ve radara eklenir. **Düzenli ödeme** seçeneğiyle sıklığı ve isteğe bağlı bitiş tarihini belirleyebilirsin. Otomatik seçilen düzenli ödemeler vadesinde gider kaydı oluşturur; bu, bankadan tahsilat doğrulaması değildir.

İleri tarihli tek seferlik gelir, giderlerle birlikte **Kayıtlar** ve **Yıllık radar** içinde bekleyen kayıt olarak görünür. Listeden doğrudan düzenlenebilir veya silinebilir. Vadesine kadar kullanılabilir bakiyeye katılmaz; vade günü kendi tarihiyle bir kez gelir kaydına dönüşür.

<table>
  <tr>
    <td align="center"><strong>Gider ekle</strong><br /><sub>Tutar, kategori ve ödeme tarihini seç.</sub><br /><br /><img src="docs/images/expense-form.png" alt="Gider formu ve ileri tarih seçimi" width="310" /></td>
    <td align="center"><strong>Düzenli ödeme</strong><br /><sub>Sıklık, otomatik kayıt ve bitiş tarihi.</sub><br /><br /><img src="docs/images/regular-payment-form.png" alt="Düzenli ödeme formunda aylık tekrar ve isteğe bağlı bitiş tarihi" width="310" /></td>
  </tr>
</table>

### 4. Gelir ve gider takvimini radarda izle

**Gelir & Gider → Yıllık radar** takviminde her ayın gelirini **+**, giderini **−** olarak görürsün. Gerçekleşmiş işlemler, ileri tarihli gelir/giderler, düzenli kayıtların vadeleri ve eski yıllık planlar birlikte gösterilir. Aynı gerçekleşmiş işlem iki kez sayılmaz; seriyi silsen bile geçmiş işlemler görünür kalır.

Yıllık toplam ve net, gerçekleşmiş kayıtlarla bekleyen planları birlikte içerir; kullanılabilir bakiye değildir. Ay seçince ayrıntılar ve **Alındı / Ödendi / Bekliyor / Gecikti** durumları açılır. Yeni planı **+ → Gelir/Gider** formundan oluştur; takvimde aynı işi yapan ekleme düğmeleri yoktur. Eski yıllık planlar düzenlenebilir ve silinebilir.

<table>
  <tr>
    <td align="center"><strong>Tüm kayıtlar</strong><br /><sub>Ay filtresini tek dokunuşla kaldır.</sub><br /><br /><img src="docs/images/records-all.png" alt="Bütün ayların gelir ve gider kayıtları" width="310" /></td>
    <td align="center"><strong>Düzenli kayıtlar</strong><br /><sub>Durdur, bitiş tarihi belirle veya seriyi sil.</sub><br /><br /><img src="docs/images/recurring.png" alt="Düzenli gelir ve giderlerin doğrudan yönetimi" width="310" /></td>
  </tr>
</table>

<table>
  <tr>
    <td align="center"><strong>Giderler</strong><br /><sub>Giderler tek dokunuşla filtrelenir.</sub><br /><br /><img src="docs/images/expenses.png" alt="Seçili ayın gider kayıtları" width="310" /></td>
    <td align="center"><strong>Yıllık radar</strong><br /><sub>Aylara dağılan gelir ve giderler.</sub><br /><br /><img src="docs/images/annual-radar.png" alt="Yıllık radar takviminde aylık artı ve eksi toplamlar" width="310" /></td>
  </tr>
  <tr>
    <td align="center"><strong>Ödeme vadeleri</strong><br /><sub>Tek seferlik ve düzenli giderler aynı listede.</sub><br /><br /><img src="docs/images/radar-payments.png" alt="Radarda internet, araç sigortası ve yıllık trafik sigortası vadeleri" width="310" /></td>
    <td align="center"><strong>Ödeme davranışı</strong><br /><sub>Bekleyen ödeme bakiyeyi etkilemez. Ödendi olarak kaydederken gerçek tutarı girebilirsin; o anda giderlere ve bakiyeye yansır.</sub></td>
  </tr>
</table>

### 5. Hedeflerini ve genel gidişatı gör

Cüzdan birikim hedeflerini ve bütçeleri; Analiz dönemlik gelir gider dengesini gösterir. Hedef tamamlandığında kartın görünümü değişir. Profil, kategori ve veri yönetimine erişim sağlar.

<table>
  <tr>
    <td align="center"><strong>Cüzdan</strong><br /><sub>Hedefe ayrılan para ve ilerleme.</sub><br /><br /><img src="docs/images/wallet.png" alt="Cüzdanda birikim hedefi, biriken tutar ve ilerleme" width="310" /></td>
    <td align="center"><strong>Hedef tamamlandı</strong><br /><sub>Tamamlanan hedefin başarı görünümü.</sub><br /><br /><img src="docs/images/goal-complete.png" alt="Tamamlanan hedefin yeşil başarı kartı ve kupa" width="310" /></td>
  </tr>
  <tr>
    <td align="center"><strong>Analiz</strong><br /><sub>Dönemin gelir, gider ve net sonucu.</sub><br /><br /><img src="docs/images/analysis.png" alt="Aylık gelir gider karşılaştırması ve dönem analizi" width="310" /></td>
    <td align="center"><strong>Profil</strong><br /><sub>Uyarılar, kategoriler ve ayarlar.</sub><br /><br /><img src="docs/images/profile.png" alt="Profilde finans özeti ve veri yönetimi seçenekleri" width="310" /></td>
  </tr>
</table>

### Daha kısa erişim yolları

Anasayfadan kayıtlar ve takvim doğrudan açılır. Cüzdanda birikim ve bütçe tek sıra sekmeyle seçilir. Profilde ayarlar, kategoriler, yedekleme, geri yükleme ve CSV dışa aktarma doğrudan görünür. Formlar görünür kapatma düğmesiyle kapanır; kompakt kartlar ve daha kısa geçişler içerik için alan bırakır.

<table>
  <tr>
    <td align="center"><strong>Bütçe</strong><br /><img src="docs/images/budget.png" alt="Cüzdandaki doğrudan bütçe görünümü" width="260" /></td>
    <td align="center"><strong>Ayarlar</strong><br /><img src="docs/images/settings.png" alt="Tema ve bildirim ayarları" width="260" /></td>
    <td align="center"><strong>Kategoriler</strong><br /><img src="docs/images/categories.png" alt="Gelir ve gider kategorilerini yönetme" width="260" /></td>
  </tr>
</table>

## Özellikler

| Ekran | Neler yapabilirsin? |
| --- | --- |
| **Anasayfa** | Hedefini, kullanılabilir bakiyeni, aylık özeti, finans yönetimi puanını ve geciken ödemeleri gör; kartları açıp kapat ve sıralarını düzenle. |
| **Gelir & Gider** | Ay ay veya bütün geçmişi gör; gerçekleşmiş ve bekleyen kayıtları düzenle, düzenli serilere ve yıllık takvime doğrudan geç. |
| **Cüzdan** | Birikim hedeflerini tarih ve aylık katkıyla planla; genel ve kategori bütçelerini izle. |
| **Analiz** | Günlük, haftalık, aylık veya yıllık dönemi seç; gelir/gider karşılaştırmasını, harcama içgörülerini, kategori dağılımını, Paranın Yolculuğu akışını ve Yıllık Radar'ı gör. |
| **Profil** | Kategorileri ve yerel bildirimleri yönet; JSON yedek oluştur/geri yükle ve Türkçe CSV aktar. |

### Daha az uğraş, daha düzenli takip

- **Tekrarlayan kayıtlar:** günlük, haftalık, aylık veya yıllık gelir ve giderler; başlangıç tarihi, isteğe bağlı bitiş tarihi, durdurma ve geçmiş kayıtları koruyarak seriyi silme seçenekleri.
- **Faturalar:** otomatik seçilenler vadede gider olarak yazılır; manuel seçilenler yalnızca ödendi işaretlenince bakiyeyi etkiler. Gerçek banka tahsilatı doğrulanmaz.
- **Bildirimler:** uygulama Android'in geçerli izin durumunu denetler; izin kapalıysa sistem ayarlarına götürür. Bütçe eşiklerine ek olarak manuel düzenli ödeme ve ileri tarihli tek seferlik giderler için vadeye 3, 2 ve 1 gün kala yerel hatırlatmalar planlanır. Teslim zamanı işletim sistemi ve pil kısıtlarına bağlıdır.
- **Arka plan:** Android WorkManager yaklaşık altı saatte bir gecikmiş otomatik kayıtları tamamlar ve hatırlatmaları yeniler. Android görevleri erteleyebilir; uygulama açıldığında kontrol ayrıca yapılır.
- **Android widget:** 1×1 hedef yüzdesi, 2×1 bakiye, 2×2 hedef, 2×3 bütçe ve 3×3 finansal özet seçenekleri vardır. Ayarlardaki görsel seçim penceresinde boyut ve içerik önizlenir. Bakiye gizlilik tercihiyle kapatılabilir; uygulama verisi değiştiğinde yenilenir.
- **Esnek formlar:** gelir kaynağı, gider adı, hedef adı ve not isteğe bağlıdır. İsimsiz kayıtlara uygun bir ad atanır.
- **Geri tuşu:** açık pencereyi kapatır, diğer sekmelerden ana sayfaya döner; ana sayfada uygulamadan çıkmaz.
- **Hızlı ekleme:** her ekrandaki **+** düğmesinden gelir, gider veya birikim hedefi oluştur.
- **Düzenlenebilir ana ekran:** başlıktaki düzenleme simgesinden hedef, aylık özet, ayrı bakiye, ayrı gelir/gider, son hareketler ve geciken ödeme kartlarını seçip sırala. Düzen cihazda saklanır. Varsayılan görünümde bakiye, gelir ve gider aylık özet kartında birlikte yer alır.
- **Finans yönetimi puanı:** son üç tamamlanmış ay ve içinde bulunulan ayın kayıtlarını; gelir/gider dengesi, bütçe limitleri, birikime yatırma ve çekme, düzenli faturalar, gelir düzeni, aylık gidişat, bakiye tamponu ve harcama dağılımı üzerinden değerlendirir. Detay ekranı her alanın puanını ve kayda dayalı yorumları gösterir. Verisi olmayan alanlar ağırlık hesabından çıkarılır; otomatik ödeme kayıtları banka tahsilatının kanıtı değildir.
- **Paranın Yolculuğu:** seçili dönemin gelirlerini, gider kategorilerini, birikime yatırma/çekmeyi ve dönemlik artışı ayrı akışlar halinde gösterir. Bir akışa dokununca onu oluşturan kayıtlar açılır. Çember grafiğinde paylar eşit kalınlıktaki dilimlerle gösterilir; dilime veya açıklamasına dokununca yüzdesi ve tutarı seçilir. Birikim aktarımı gelir veya gider sayılmaz.
- **Yıllık radar:** Kayıtların yanındaki sekmeden açılır; gerçekleşmiş ve bekleyen gelir/giderleri her ay için +/− toplamlarla gösterir. Yıllık tekrarı gelir/gider formundan seçebilirsin. Bekleyen ödemeler bakiyeyi değiştirmez; ödendi olarak kaydedilenler giderlere eklenir. Ödenen tutar planlanandan farklı girilebilir.
- **Aylık birikim sözü:** her hedefe isteğe bağlı aylık tutar ve ayın son gününü ekleyebilirsin. Vade geçince eksik tutar hedef kartında ve Profil uyarısında görünür; zamanında ve gecikmeli yatırımlar finans puanında ayrı değerlendirilir. Eski hedefler kendiliğinden gecikmiş sayılmaz.
- **Profil ve yedek:** Profil, en önemli güncel uyarıyı ve son yedek tarihini gösterir. JSON yedeği güncel veri şemasını, aylık planları, ekran tercihlerini ve kurulu uygulamanın sürümünü taşır.
- **Android'de dosya kaydetme:** JSON yedeği ve CSV, sistemin belge oluşturma ekranında seçtiğin konuma yazılır. İptal edilen işlem son yedek tarihini değiştirmez.
- **Başarı görünümü:** hedef tamamlandığında kart yeşile döner; altın kupa, parıltılar ve yeni hedef düğmesi belirir.
- **Tema ve hareket tercihi:** varsayılan olarak sistem temasını anlık takip etme; isteğe bağlı açık/koyu tema seçimi, animasyonları kapatma ve onaylı veri silme.
- **Sürüm bilgisi:** uygulama başlığı, açılış ekranı ve ayarlarda kurulu paketin sürümü gösterilir.

### Hareketli bir deneyim

Birikio açılırken logonun katmanları birleşir, altın para yerine oturur ve uygulama adı belirir. Alt sekmeler arasındaki geniş dalga, seçilen sekmenin yönüne doğru kayar. Gelir & Gider, Cüzdan ve Analiz içindeki görünümler bulanıklıkla açılır; hareket azaltma tercihi bu geçişlere de uygulanır.

Yarış motorunun dönen jantları ve kayan yol çizgileri, diğer hedeflerin kendilerine özgü hareketleri, para ekleme/çekmedeki yeşil–kırmızı banknotlar, gelir/gider eklemedeki yönlü ışık parçacıkları ve animasyonlu ilerleme göstergeleri hedeflerini görünür kılar. Azaltılmış hareket tercihinde açılış ve kayıt animasyonları atlanır.

## Kurulum

**Gereksinimler:** Dart `^3.12.2` ile uyumlu Flutter SDK; Android için Android SDK ve bir emülatör veya USB hata ayıklaması açık cihaz. iOS derlemesi için macOS ve Xcode gerekir.

Proje klasöründe:

```sh
flutter pub get
flutter devices
flutter run
```

Birden fazla cihaz varsa:

```sh
flutter run -d <cihaz-kimliği>
```

Android'de yerel deneme için:

```sh
flutter build apk --debug
```

Bu debug APK'si geliştirme/test içindir. Telefona verileri koruyan **güncelleme APK'si** teslim etmek için `pubspec.yaml` içindeki `+` sonrasındaki sürüm kodunu önceki teslimden büyük yap, README'yi ve gerektiğinde görselleri güncelle, ardından Windows PowerShell'de şunu çalıştır:

```powershell
pwsh -File tools/build_update_apk.ps1
```

Betik analiz ve testlerden sonra release APK'sini derler; aynı özel anahtarla imzalar ve paket kimliği, sürüm kodu ile sertifika parmak izini doğrulamadan masaüstüne kopyalamaz. Son teslim kodunu `tools/update_identity.json` içinde günceller; bu dosyayı da değişikliklerle birlikte commit et. Eski anahtar `~/.android/debug.keystore` konumunda bulunmalıdır. Anahtarın güvenli bir çevrimdışı kopyasını sakla; **yeni debug anahtarı üretmek aynı imzayı sağlamaz**. Bu anahtarı repoya ekleme.

Telefonunda önceki Birikio APK'si yüklüyse güncelleme için `com.bekirturgut.birikio` paket kimliği, **aynı imza sertifikası** ve daha yüksek `versionCode` gerekir. Son teslim `1.1.0+3` değerini kullanır. Kurmadan önce **Profil → JSON yedek oluştur**; APK'yi mevcut uygulamanın üzerine **Güncelle** ile kur. Kaldırma veya uygulama verilerini temizleme yerel kayıtları silebilir. İmza uyuşmazlığı yüzünden Android kaldırma isterse işlemi durdur ve yedeği al.

> README görselleri Flutter widget testinde gerçek arayüz bileşenlerinden üretilir. iOS cihaz derlemesi henüz doğrulanmamıştır.

## Veriler ve hesaplama

### Cihazında kalır

Uygulama sunucu, kullanıcı hesabı veya internet bağlantısı gerektirmez. Kayıtlar `SharedPreferencesAsync` üzerinden sürümlü yerel JSON olarak tutulur; Android tarafında DataStore kullanılır. Eski sürümsüz kayıtlar açılırken korunur. Uygulama içinde analitik veya ağ çağrısı bulunmaz ve Android otomatik yedekleme kapalıdır.

Profil > Ayarlar > Verilerim bölümünde JSON yedeği cihazına kaydedebilir, geri yükleyebilir veya gelir/gider kayıtlarını CSV olarak aktarabilirsin. Geri yükleme mevcut yerel veriyi yedekteki veriyle değiştirir; önce onay istenir.

Tutarlar **tam sayı kuruş** olarak saklanır. Kaydetme başarısız olursa bellekteki değişiklik geri alınır. Açılışta veriler okunamazsa mevcut kayıtları koruyan bir tekrar deneme ekranı gösterilir.

### Bakiye nasıl hesaplanır?

```text
Kullanılabilir bakiye = Toplam gelir − Toplam gider − Ayrılmış net birikim
```

Örneğin 10.000 ₺ gelir, 2.000 ₺ gider ve hedefe ayrılmış 3.000 ₺ varsa kullanılabilir bakiye **5.000 ₺** olur.

- Birikime aktarma bir gider, birikimden çekme bir gelir sayılmaz.
- Hedef silinirse o hedefe ayrılan tutar kullanılabilir bakiyeye döner.
- Aylık bütçe limiti, bakiyeyi değiştirmeyen bir harcama planıdır.
- Birikim hedef tutarının altına düşerse başarı kartı tekrar ilerleme görünümüne döner.
- İleri tarihli tek seferlik giderler vadesine kadar bekleyen ödeme olarak tutulur; ödendi işaretlenince bakiyeye yansır.
- İleri tarihli tek seferlik gelirler de vadesine kadar bakiyeye girmez; vadesinde otomatik olarak gelir kaydı oluşturulur.

### Otomatik kayıtlar ne zaman eklenir?

Tekrarlar açılışta, uygulama ön plana geldiğinde, açıkken dakikada bir ve Android'in izin verdiği periyodik arka plan görevinde kontrol edilir. Android arka plan görevini geciktirebilir; kaçırılan dönemler en geç sonraki açılışta kendi tarihleriyle tamamlanır.

Aynı dönem iki kez eklenmez; silinmiş otomatik kayıt yeniden oluşturulmaz. Aylık tekrar başlangıç gününe bağlı kalır: **31 Ocak → 28/29 Şubat → 31 Mart**.

Tekrardan oluşan bir kaydı düzenlerken yalnızca o kayıt, o ve sonraki kayıtlar veya tüm seri kapsamını seçebilirsin. Düzenli ödeme kartında gelecek tutarı ve vade gününü değiştirebilir; tekrarın bitiş tarihini ayarlayabilirsin. Sıklığı değiştirmek için mevcut seriyi durdurup yeni bir seri oluşturabilirsin.

> **Mevcut sınırlar:** cihazlar arası otomatik eşitleme yoktur. JSON yedeğiyle elle taşıma mümkündür. Uygulamayı kaldırmak veya uygulama verilerini temizlemek yerel kayıtları silebilir.

## Geliştirme

**Altyapı:** Flutter · Dart · Material 3 · `ChangeNotifier` · `SharedPreferencesAsync` · Flutter yerelleştirme araçları · `package_info_plus`.

```text
lib/
├── main.dart             # Uygulama başlangıcı
├── data/
│   ├── store.dart        # Modeller, hesaplar, tekrarlar ve yerel saklama
│   ├── analytics.dart    # Dönem karşılaştırmaları
│   ├── money_journey.dart # Dönemlik para akışı hesabı
│   ├── annual_radar.dart # Gelir/gider yıllık takvimi ve plan hesabı
│   ├── financial_health.dart # Finans yönetimi puanı ve yorumlar
│   ├── goal_plan.dart   # Aylık hedef vadeleri ve eksik tutar
│   ├── backup.dart       # JSON yedek ve CSV aktarımı
│   └── finance_document.dart # Veri şeması ve eski kayıt geçişi
├── services/             # Bildirimler ve Android ana ekran widget'ları
└── ui/
    ├── app.dart          # Tema, navigasyon ve ana ekranlar
    ├── forms.dart        # Kayıt, hedef ve aktarım formları
    ├── reports.dart      # Bütçe, dönem analizi ve içgörüler
    ├── money_journey.dart # Para akışı görünümü
    ├── annual_radar.dart # Gelir/gider yıllık takvimi görünümü
    ├── orbit_chart.dart  # Etkileşimli halka grafik
    ├── palette.dart      # Temaya uygun finans renkleri
    ├── widgets.dart      # Ortak bileşenler ve görsel animasyonlar
    ├── brand.dart        # Birikio logosu
    ├── launch.dart       # Animasyonlu açılış ve veri yükleme
    ├── app_version.dart  # Kurulu uygulama sürümü
    └── widget_picker.dart # Widget seçim penceresi
```

### Kontroller

Bu depoda çalışan asistanlar için kalıcı kurallar [AGENTS.md](AGENTS.md) dosyasındadır: her değişiklikte README güncellenir; arayüz değiştiyse ilgili ekran görüntülerinin güncelliği kontrol edilir ve gerekiyorsa yeniden üretilir. Güncelleme APK'si tesliminde [kimlik denetimi](tools/check_update_identity.ps1) zorunludur.

```sh
flutter analyze
flutter test
```

Testler; para ayrıştırma, ay sonu ve artık yıl davranışları, tekrarların tekilleştirilmesi, aktarım bakiyesi, kalıcılık, veri geçişi, bütçe ve fatura hesapları, para akışı, yıllık planlar, dar ekran yerleşimi, tema kontrastı, widget seçimi, hedef tamamlama ve açılış akışlarını kapsar. Kayıt erişimi testleri boş seçili aydan geçmişe erişimi, yeni kayıt eklerken eski arama/filtrelerin temizlenmesini, bekleyen gelir/gider düzenlemeyi ve radardaki +/− tutarların tek sayılmasını doğrular.

### Görselleri yeniden üretme

README'deki 18 ekran görüntüsü uygulamanın gerçek bileşenlerinden, bellekte tutulan kurgu örnek verilerle üretilir. Kendi Flutter SDK yolunu ver:

```sh
flutter test tools/capture_readme.dart --dart-define=FLUTTER_SDK=C:/flutter
```

Logo ve platform simgelerini üretmek için Python ve Pillow gerekir:

```sh
python -m pip install pillow
python tools/generate_icon.py
python tools/readme_banner.py
```

[Düzenlenebilir SVG logo](docs/images/birikio-logo.svg) · [Uygulama simgesi](artifacts/birikio-icon-round.png)

---

<p align="center"><strong>Birikio</strong><br /><sub>Küçük adımlar. Büyük birikimler.</sub></p>

