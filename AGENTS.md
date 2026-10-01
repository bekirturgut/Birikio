# Birikio çalışma kuralları

Bu dosya bu depoda çalışan tüm kod asistanları için kalıcı talimattır. Kullanıcının o anki açık isteği önceliklidir.

## Güncelleme APK'si ve veri sürekliliği

- Android `applicationId` ve `namespace` değerlerini `com.bekirturgut.birikio` olarak koru. Kotlin paket adını, yerel veri anahtarı `pusula.local.v1` değerini ve JSON yedek biçimi `birikio-backup` değerini keyfi olarak değiştirme. Gerekli bir değişimde önce geriye uyumlu veri geçişini yaz ve test et.
- iOS paket kimliği (`com.example.gelirGider`) iOS geliştirmesi yapılırken de sessizce değiştirilmemelidir; Android güncelleme denetimi Android kimliğine odaklanır.
- Kullanıcının telefonundaki kurulumla aynı sertifikayı kullan: SHA-256 `6f90672e47a83cd44ee10e3c85d4e94db046260e050d87070ed23aabae6b86b4`. Mevcut özel anahtar `~/.android/debug.keystore`, takma adı `androiddebugkey`. Anahtarı ve parolaları git deposuna ekleme. Anahtar bulunamaz veya parmak izi farklıysa APK'yi güncelleme diye teslim etme.
- Her teslim edilen APK'de `pubspec.yaml` içindeki `versionCode` değerini son teslimden büyük yap. `tools/update_identity.json` son teslim kodunu tutar.
- Güncelleme APK'si için `tools/build_update_apk.ps1` kullan. Betik kaynak kimliklerini ve anahtarı derlemeden önce, paketin kimliğini ve imzasını teslimden önce denetler. Doğrudan üretilmiş imzasız ya da farklı imzalı APK'yi kullanıcıya verme.
- Kurulum yönergesinde mevcut uygulamayı kaldırmadan **Güncelle** seçeneğiyle üzerine kurmayı ve kurulumdan önce uygulamadan JSON yedek almayı belirt. Android'deki normal güncelleme veriyi korur; kaldırma veya uygulama verilerini temizleme yerel kayıtları silebilir. Yedek varmış gibi varsayma.
- `android:allowBackup="false"` mevcut gizlilik tercihidir. Bunu değiştirirken bulut yedeklemenin etkilerini kullanıcıya açıkla; sessizce açma.

## Her değişiklikte belge ve doğrulama

- Kod veya kullanıcı akışı değişen her işte README'yi aynı commit içinde güncelle. Davranışı, kurulum adımını ve bilinen sınırları doğru anlat.
- Ön yüz değişikliklerinde README görsellerinin hâlâ güncel olup olmadığını kontrol et. Görünümü veya anlatımı etkileyen değişiklikte `tools/capture_readme.dart` ile ilgili ekran görüntülerini yeniden üret ve incele.
- İlgili testleri, `flutter analyze` komutunu ve APK tesliminde Android derlemesini çalıştır. Hata çıkarsa düzeltip yeniden doğrula. Sonuçları kullanıcıya açıkça bildir.
- Kullanıcının önceden değiştirdiği dosyaları geri alma veya ilgisiz dosyaları commit'e katma.
