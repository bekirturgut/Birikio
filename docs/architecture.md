# Mimari

- `lib/data/store.dart`: yerel finans modeli, hesaplamalar, tekrar üretimi ve `SharedPreferencesAsync` kalıcılığı. Tutarlar tam sayı kuruştur.
- `lib/data/finance_document.dart`: sürümlü eski veri geçişi.
- `lib/data/analytics.dart`: dönem içgörüleri ve bütçe puanı.
- `lib/data/backup.dart`: yedek doğrulama ve CSV üretimi. Geri yükleme mevcut veriyi doğrulamadan değiştirmez.
- `lib/services/`: Android/iOS yerel bildirimleri ve Android widget özeti.
- `lib/ui/`: ekranlar, formlar ve görsel bileşenler.

Yerel saklama anahtarı `pusula.local.v1` olarak korunur. Otomatik faturalar tekrar motorunda, manuel faturalar ödeme işaretlendiğinde giderleşir. Bütçe ve birikim aktarımı gelir/gider kaydı değildir. Şimdiki veri boyutu için ayrı veritabanı gerekli görülmedi; kayıt sayısı ve açılış süresi artarsa bu karar yeniden değerlendirilmeli.

Android dağıtım imzası için yerel `android/key.properties` dosyası gerekir (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). Dosya ve anahtar deposu git tarafından yok sayılır. Uygulama yayımlanmadığı doğrulandıktan sonra kalıcı Android kimliği `com.bekirturgut.birikio` seçildi. Eski `com.example.gelir_gider` debug kurulumu ayrı bir uygulamadır; veriler gerekiyorsa eski sürümden JSON yedek alıp yeni sürümde geri yüklenmelidir.
