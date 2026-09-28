# Birikio yapılacaklar

Bu dosya, 28 Eylül 2026 tarihli repo inceleme sohbeti ve ardından verilen kararların uygulama planıdır. Her iş tamamlandığında kutusu işaretlenir; kapsam değişirse önce burası güncellenir.

**Durum:** İşaretli maddeler tamamlandı. Gelir & Gider ve Cüzdan sekmeleri ile Profil ekranı eklendi; aşağıdaki açık kutular hâlâ yapılacak işleri gösterir.

## Kapsam ve temel kararlar

- Banka bağlantısı, banka hesabı/cüzdan sistemi ve hesaplar arası transfer bu planda yok. Uygulama gerçek banka hareketlerini veya kart tahsilatını doğrulamaz.
- Mevcut yerel çalışma ve ücretsiz Firebase Spark planıyla uyum korunur. Çoğu özellik cihazda yapılır; Cloud Storage ve Cloud Functions gerektiren otomatik bulut yedeği/sunucu bildirimi kapsam dışıdır.
- Mevcut kullanıcı verisi korunur. Yeni alanlar eski kayıtlar için güvenli varsayılanlarla okunur; geri yükleme ve veri geçişleri test edilir.
- Tutarlar kuruş cinsinden tam sayı olarak kalır. Bütçe, hedef aktarımı, gelir/gider ve fatura ödeme durumları birbirine karıştırılmaz.

## Önerilen uygulama sırası

1. Veri geçişinin temeli ve kritik kod ayrımı (12): mevcut kayıtlar yeni alanlar eklendikçe açılmaya devam etmeli.
2. Birleşik **Gelir & Gider** ekranı ve özel kategoriler (5): diğer ekranların kullanacağı kategori yapısı burada oluşur.
3. Kategori bütçeleri (3): özel kategorilere bağlanır.
4. Birikim hedefi planlaması (4): diğer modüllerden bağımsız ilerleyebilir.
5. Gelişmiş işlem filtreleri ve tekrar serisi düzenleme (6): fatura akışının kullanacağı tekrar kuralları burada netleşir.
6. Düzenli ödemeler ve faturalar (7): ödeme durumu ve gider oluşturma davranışı tamamlanır.
7. Bütçe ve fatura bildirimleri (10): tamamlanan limit ve ödeme durumlarına bağlanır.
8. Gelişmiş analizler (8): yeni kategori, bütçe ve ödeme verisini kullanır.
9. Ana ekran finansal özet ve bütçe yönetimi puanı (9): tamamlanan hesaplamalara dayanır.
10. Ana ekran widget'ı (11): son hâliyle belirlenen özetleri gösterir.
11. JSON yedekleme/geri yükleme ve dışa aktarma (1): oluşan veri modelinin tamamını kapsar.
12. Yayın ve GitHub hazırlığı (13): son kontroller, CI ve belgeler güncellenir.

**Sıra notu:** 1 numaralı iş bu listede 11. sıraya taşındı; bölüm numaraları önceki sohbetle eşleşmesi için korunuyor. Buna karşılık 12 numaradaki eski veriyi okuyabilme ve veri geçişi altyapısı en başta yapılır. Büyük model değişikliklerinden önce mevcut yerel JSON ile geri yükleme senaryosu test verisi olarak saklanır; kullanıcı verisi sessizce sıfırlanmaz.

## 1. Yedekleme, geri yükleme ve dışa aktarma

- [x] Ayarlara **Verilerim** bölümü ekle: JSON yedek oluştur, dosyadan geri yükle, CSV dışa aktar.
- [x] Yedek dosyasına `schemaVersion`, oluşturulma zamanı, uygulama sürümü ve tüm finans verilerini ekle.
- [x] Geri yüklemede dosya türünü, sürümünü, alanları, kimlikleri ve tutarları doğrula; bozuk/uyumsuz dosyada mevcut veriye dokunma.
- [x] Geri yüklemeden önce kullanıcıya hangi verinin değişeceğini göster; başarılı işlemden sonra hesaplamaları ve ekranları yenile.
- [x] Eski sürümlü veriyi geçiş katmanından geçir; aynı yedeğin tekrar yüklenmesinde çift kayıt oluşmasını engelle.
- [x] CSV'yi gelir/gider kayıtları için açık tarih, tutar, tür, kategori ve not sütunlarıyla üret; Türkçe elektronik tablo uyumluluğu için UTF-8 BOM ve noktalı virgül kullan.
- [x] Excel ve PDF dışa aktarmayı değerlendirdik: şu aşamada CSV ve JSON ihtiyacı karşılıyor, ayrı format eklenmeyecek.

**Bitti sayılması:** Yedek başka bir kurulumda geri yüklenebilir; bozuk dosya veri kaybettirmez; eski veriler uygulama güncellemesinden sonra açılır.

## 2. Hesap/cüzdan sistemi — kapsam dışı

- [x] Bu aşamada banka/cüzdan hesabı, hesap bazlı bakiye ve hesaplar arası transfer yapılmayacak.

**Not:** Kullanıcının elle tanımladığı banka hesabı banka entegrasyonu gerektirmez; gerçek banka hareketlerini otomatik çekmek ayrı bir entegrasyondur. Mevcut tek toplam bakiye modeli devam eder.

## 3. Kategori bazlı bütçe

- [x] Mevcut aylık genel limiti koruyarak gider kategorilerine ay bazında ayrı limit ekle.
- [x] Kategori kartlarında limit, harcanan, kalan/aşılan tutar ve yüzdeyi göster.
- [x] Kategori limiti olmayan giderlerin genel bütçedeki yerini açık göster; kategori limitleriyle genel limitin ayrı planlar olduğunu belirt.
- [x] Kategori yeniden adlandırma/silme ve eski işlemlerle ilişki kurallarını özel kategorilerle birlikte belirle.
- [x] Ay değişimi, sıfır limit, bütçe aşımı ve eski bütçe verisi için hesaplama testleri ekle.

**Bitti sayılması:** Kullanıcı hem ayın toplamını hem kategori bazında sınırlarını görür; eski aylık bütçesi kaybolmaz.

## 4. Birikim hedefi planlaması

- [x] Hedef formuna isteğe bağlı hedef tarihi ve planlanan aylık katkı ekle.
- [x] Hedef kartında biriken, kalan, hedef tarihi ve hedefe yetişmek için yaklaşık aylık gereken tutarı göster.
- [x] Geçmiş tarih ve tamamlanmış hedef durumlarını ele al; para ekleme/çekme sonrası hesabı güncelle.
- [x] Tahmini tamamlanma tarihini yalnızca planlanan aylık katkı varsa göster; varsayımı açık yaz.
- [x] Yeni alanları sürümlü veri geçişine dahil et. Dışa aktarılabilir yedekleme henüz sonraki aşamada.

**Bitti sayılması:** Tarih vermeyen mevcut hedefler çalışır; tarih veren hedefin hesapları anlaşılır ve tutarlıdır.

## 5. Özel kategoriler ve birleşik Gelir & Gider ekranı

- [x] Alt menüdeki ayrı **Gelir** ve **Gider** sekmelerini tek **Gelir & Gider** sekmesinde birleştir.
- [x] Sayfanın üstüne **Tümü / Gelirler / Giderler** seçimi koy; kayıtlar tarih sırasıyla gösterilsin. Kategoriye göre filtreleme eklendi.
- [x] Arama ve kayıt ekleme/düzenleme/silme akışlarını yeni sayfada koru; eklerken gelir veya gider türü seçilsin.
- [x] Kullanıcının gelir ve gider için ayrı özel kategoriler oluşturmasını, yeniden adlandırmasını ve yönetmesini sağla.
- [x] Varsayılan kategorileri koru. Silinen kategorinin eski işlemleri ve tekrarları kendi adıyla kalır; yeniden adlandırmada ilgili işlemler ve tekrarlar güncellenir. Kategori bütçeleri eklendiğinde aynı kural onlara da uygulanacak.
- [x] Alt menü sayfa indeksleri, geri tuşu, hızlı ekleme ve mevcut ekran testlerini güncelle.

**Bitti sayılması:** Tek sayfada tüm hareketler ve iki ayrı filtre çalışır; mevcut kayıtlar aynı kategorileriyle görünür.

## 6. Gelişmiş filtreler ve tekrarlayan işlem düzenleme

- [x] Gelir & Gider sayfasına tarih aralığı, kategori, tutar aralığı, tekrar durumu ve sıralama filtreleri ekle; filtreleri temizleme kolay olsun.
- [x] Tekrarlayan kayıt düzenlerken **yalnızca bu kayıt / bu ve sonraki kayıtlar / tüm seri** seçeneklerini ekle. Tarih ve sıklık bu akışta değişmez.
- [x] Geçmiş gerçekleşmiş kayıtlar ve gelecek oluşumlar için kapsamı uygula; kullanıcı tarafından silinen oluşumlar yeniden üretilmez.
- [x] Aynı dönem için çift kayıt üretilmesini engelle; ayın 29–31'i ve artık yıl davranışını koru.
- [x] Düzenleme, durdurma ve uygulama yeniden açılışında tekrar motorunun birleşik senaryolarını test et; geri yükleme testi yedek bölümünde eklendi.

**Bitti sayılması:** Kullanıcı değişikliğin hangi kayıtlara uygulanacağını bilir; geçmiş ve gelecek kayıtlarda kayıp/çoğalma olmaz.

## 7. Abonelikler ve faturalar

- [x] **Düzenli ödemeler** görünümü oluştur: ad, tutar, kategori, vade, sıklık, sonraki ödeme ve aylık/yıllık yaklaşık toplam.
- [x] Gider eklerken **fatura/abonelik** türünü ve **otomatik ödeniyor mu?** seçeneğini sun.
- [x] Otomatik seçilen ödemede vadeye bağlı gider kaydı oluştur; bu, bankadan tahsilat doğrulaması anlamına gelmez.
- [x] Manuel ödemede **Bekliyor / Ödendi / Gecikti** durumları ve ödeme tarihi tut; kullanıcı “Ödendi” dediğinde gider kaydı oluştur.
- [x] Aynı faturayı iki kez gider yazmayı önle; tutar ve vade günü değişikliğini sonraki dönemlerden başlat, geçmiş ödeme kayıtlarını koru.
- [x] Ana ekranda gecikmiş ödeme uyarısı ve düzenli ödemeler sayfasına geçiş ekle.

**Bitti sayılması:** Manuel fatura ödenmeden bakiyeyi düşürmez; otomatik kayıtlar tekrar motoruyla tutarlı üretilir; gecikme görünür.

## 8. Gelişmiş analiz

- [x] Önceki aya/döneme göre gelir ve gider değişimini göster.
- [x] Günlük ortalama harcama, en çok harcanan kategori ve en yüksek harcama gününü ekle.
- [x] Ay sonu harcama ve bütçe aşımı tahminlerini yeterli veri varsa göster; hesaplama varsayımını belirt.
- [x] Gelir/gider analizi ile hedefe aktarılan net birikimi ayrı tut; negatif net aktarımı işaretli göster.
- [x] Boş veri, eksik dönem ve ay uzunluğu farklılıklarında hesaplama testleri ekle.

**Bitti sayılması:** Analizler seçilen döneme göre doğru değişir; tahminler gerçekleşmiş işlem gibi sunulmaz.

## 9. Ana ekran finansal sağlık özeti ve bütçe yönetimi puanı

- [x] Bu ayın gelir, gider, hedefe ayrılan net birikim ve birikim oranını tek kartta göster.
- [x] 0–100 arası **bütçe yönetimi puanı** için açıklanabilir bir formül belirle; limit yoksa puan yerine yönlendirme göster.
- [x] Puanın hangi verilerden hesaplandığını ekranda açıkla.
- [x] Ay başında, limit değişince ve harcama silinince puanı yeniden hesapla.

**Bitti sayılması:** Kullanıcı puanın neden yükselip düştüğünü anlayabilir; bütçe yokken keyfi puan gösterilmez.

## 10. Bütçe ve ödeme bildirimleri

- [x] Genel ve kategori limitlerinde %25, %50, %75 eşik uyarılarını tanımla; her eşik ay/kategori başına bir kez gönderilsin.
- [x] Limit değişimi, geçmiş tarihli gider ekleme ve gider silme durumlarında daha önce gönderilen eşikleri tekrar bildirmeme kuralını belirle.
- [x] Manuel faturalar için vade yaklaşırken yerel bildirim planla; ödeme işaretlenince bildirimi iptal et.
- [x] Geciken ödemeleri ana ekranda göster; ayrı gecikme bildirimi göndermeyerek bildirim sayısını sınırla.
- [x] Bildirim iznini ayardan açılırken iste; izin verilmezse uygulama içi uyarılar yine çalışsın.
- [ ] Android/iOS zamanlama ve pil kısıtlarını gerçek cihazda kontrol et. Kesin dakikada teslim garantisi verme.

**Bitti sayılması:** Eşik ve vade uyarıları tekrara boğmaz; izin kapalıyken de uygulama içindeki durum doğrudur.

## 11. Birikio ana ekran widget'ı

- [x] Android widget için ayrı 1×1 hedef yüzdesi, 2×1 bakiye, 2×2 hedef, 2×3 bütçe ve 3×3 finansal özet tasarla; dokununca uygulama açılsın.
- [x] Yerel veriden widget'a özet aktar ve veri değişince widget'ı güncelle; emülatör launcher üzerinde 3×3 görünümü ve uygulamadan açılmasını doğrula. Uygulama kapalıyken veri kendiliğinden değişmediği için widget son kaydedilen özeti gösterir.
- [x] Beş boyutu, açık/koyu tema, gizlilik ve boş veri görünümünü tasarla; 2×2 önizlemeyi ve 3×3 açık/koyu görünümü emülatörde kontrol et.
- [x] iOS WidgetKit uzantısını ayrı aşama olarak değerlendir; bu ortamda macOS/Xcode olmadığı için iOS widget eklenmedi.

**Bitti sayılması:** Kullanıcı cihazının ana ekranına Birikio widget'ını ekleyebilir ve güncel özeti görebilir.

## 12. Veri ve kod mimarisi

- [x] `FinanceStore` sorumluluklarını ihtiyaç çıktıkça ayır: veri geçişi, analiz, yedekleme ve cihaz servisleri ayrı dosyalarda; tekrar üretimi mağazada kalıyor.
- [x] Eski yerel JSON için sürümlü, geri uyumlu okuma ve geçiş katmanı kur. Mevcut saklama anahtarını ve veriyi düşünmeden değiştirme. (Sürüm 0 → 1 → 2 → 3 → 4 temeli; sonraki özelliklerde yeni geçişler eklenecek.)
- [x] Kategorilere kalıcı kimlik ekle; genel/kategori bütçesi kimliğini ay ve kategori kimliğinden türet; faturalar tekrar kuralı kimliğini kullanır. Geri yüklemede kimlik ve tutar doğrulaması uygula.
- [x] Yerel veritabanını `docs/architecture.md` içinde değerlendirdik; mevcut veri hacmi için zorunlu değil, büyürse yeniden bakılacak.
- [x] Kritik para hesabı, tekrar, yedek geri yükleme ve göç testlerini koru; her aşamada `flutter analyze` ve `flutter test` çalıştır.

**Bitti sayılması:** Yeni özelliklerin sorumlulukları ayrışır; önceki sürümün kayıtları açılır ve hesaplama davranışı korunur.

## 13. Yayın ve GitHub hazırlığı

- [x] Uygulamanın yayımlanmadığı kullanıcı tarafından doğrulandı; Android `applicationId` `com.bekirturgut.birikio` seçildi. Eski debug kurulumu için JSON yedek/geri yükleme gerekir.
- [x] Dağıtım imzalama yapılandırmasını debug imzasından ayır; gizli anahtarları repoya koyma. Yayın imzası için yerel anahtar dosyası henüz sağlanmadı.
- [x] Paket adı `birikio`, uygulama görünen adı Birikio ve Android kimliğini hizala; sürüm 1.0.0+1.
- [x] GitHub Actions'ta bağımlılık kurma, `flutter analyze`, `flutter test` ve debug APK derlemesini ekle.
- [x] `CHANGELOG.md`, MIT `LICENSE`, `CONTRIBUTING.md` ve `docs/architecture.md` ekle; README'yi güncelle.
- [ ] Android gerçek cihazda, iOS hedefleniyorsa macOS/Xcode ve gerçek cihazda yayın öncesi doğrulama yap.

**Bitti sayılması:** Sürüm üretimi tekrarlanabilir, test kapısı çalışır ve dağıtım kimliği/imzası bilinçli seçilmiştir.
