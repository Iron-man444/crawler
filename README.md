# Bilgi ve fırsat radarı — Telegram

24 Eylül 2026 — **Ruby ile ilk çalışan sürüm (0.1.0).** Eğitim/bootcamp/sertifika ve indirim/fiyat takibi şimdilik ertelendi.

Belirlenen siteler veya SerpAPI üzerinden Google sorgularıyla bulunan bilgiler genel HTML/sitemap okuyucusuyla toplanır. Gemini veya Mistral analizinden sonra tag/kelime kuralları uygulanır; PostgreSQL kuyruğundan Telegram'a aktarılır. Tek bir etkinlik türüyle sınırlı değildir. **Web/TUI, blog ve CRM/ERP sonraki aşamalardır.**

## Başlangıç

Ruby 3.3/3.4 ve PostgreSQL gerekir. [Kurulum ve kullanım belgesindeki](docs/UYGULAMA.md) adımlarla `config/settings.json` ve ortam değişkenlerini hazırlayın.

```sh
bundle install
ruby bin/radar validate
ruby bin/radar migrate
ruby bin/radar run
```

İkinci terminalde `ruby bin/telegram`. Hazır gönderici de Ruby'dir; kendi Python botunuz için claim/ack API'si kullanılabilir. İkisini birlikte çalıştırmanız gerekmez. Docker Compose seçeneği de vardır.

Test: `bundle exec ruby scripts/test.rb`. PostgreSQL entegrasyon testleri `RADAR_TEST_DATABASE_URL` ister. Gerçek API anahtarı gerekmez; dış servisler testlerde taklit edilir. Canlı kaynak taraması veya Telegram gönderimi henüz başlatılmadı.

Örnek profil pasif gelir. Gerçek kaynaklar ve API model kimliği seçilmelidir. JavaScript render/Firecrawl ve yerel LLM bu ilk sürümde yoktur; diğer sınırlar [uygulama belgesinde](docs/UYGULAMA.md#testler-ve-açık-sınırlar).

## Belgeler

| Belge | İçerik |
|---|---|
| [Uygulama kurulumu ve mevcut özellikler](docs/UYGULAMA.md) | Ruby, PostgreSQL, Gemini/Mistral, Telegram, Docker ve bot API'si |
| [Sunucu aktarımı ve kısa test](docs/SUNUCU_KURULUMU.md) | SSH, ayrı test veritabanı ve GitHub güncelleme akışı |
| [Güncel teknik görev dokümanı](docs/TEKNIK_GOREV_DOKUMANI.md) | Sabit site + Google sorgusu, yerel/API LLM, rate-limit/engel yönetimi, Telegram sözleşmesi, Windows/Ubuntu görevleri |
| [AWS kapasite ve ücretsiz kullanım notu](docs/AWS_KAPASITE_NOTU.md) | Ubuntu/Windows seçimi, küçük EC2 kapasitesi, API/yerel LLM farkı ve güncel ücretsiz kullanım koşulları |
| [Güncel kaynak adayları](arastirma/firsat_radari_kaynaklari.json) | Kommunity, Meetup, Techcareer, Telegram, belirsiz Expo İstanbul adresi ve ek adaylar |
| [Önceki geniş kaynak araştırması](docs/KAYNAK_ARASTIRMASI.md) | Tüm sektörlere yönelik 24 kaynak; güncel aktif kapsam olarak kullanılmaz |
| [Önceki kaynak envanteri](arastirma/kaynaklar.json) | Tarihsel araştırma verisi; yeni listeye otomatik dahil değildir |
| [Rakip özellik analizi](docs/RAKIP_OZELLIK_ANALIZI.md) | Araştırma referansı; önceliklerde güncel Telegram odaklı sürüm 3 esas |
| [ERP sahibine iletilecek talep](docs/ERP_ENTEGRASYON_TALEBI.md) | Özellik değerlendirme tablosu, alan eşlemeleri ve önerilen entegrasyon sözleşmesi |
| [Önceki genel yol haritası](TEKNIK_YOL_HARITASI.md) | İlk ürün/fiyat örneğiyle hazırlanmış tarihsel plan; güncel kapsam için teknik görev dokümanı esas |

## Ekip için düzenlenmiş kısa görev metni

Belirlenen siteler düzenli taranacak; Google gelişmiş sorgularından da yeni adresler keşfedilecek. Site başına elle selector yazmadan genel okuyucuyla içerik alınacak. LLM bilgileri çıkarıp alakasızları eleyecek; kullanıcıya ait tag/kelime ve isteğe bağlı konum, tarih, tür kuralları uygulanacak. Etkinlik, buluşma, iş ortaklığı, haber, duyuru veya başka bilgi için ayrı takip profilleri tanımlanabilecek. Eğitim ve indirim profilleri bu sürümde açılmayacak.

Kullanıcının son tercihiyle ana servis Ruby'dir. PostgreSQL ve Ruby, Windows/Ubuntu hedefiyle çalışır. İlk sürüm Gemini/Mistral API adaptörlerini içerir; yerel model sonraki aşamadadır. Hazır Ruby göndericisi veya kullanıcının Python botu kalıcı bildirim işlerini alıp Telegram'a gönderir ve sonucu bildirir. Yapılandırma dosyası ve CLI yeterlidir.

Hız/kota yönetimi kaynak ve sağlayıcı bazında ortak uygulanacak. 429 için bekleme, geçici hatada sınırlı retry, API kotası bitince duraklama; 403/CAPTCHA durumunda yetkili erişim veya alternatif açık kaynak değerlendirmesi yapılacak. Önbellek ve artımlı kontrol gereksiz istekleri azaltacak. Proxy döndürerek kaynak sınırını delmek bu planın parçası değil.

## Araştırma sonucu ve açık noktalar

- TechAnkara Proje Pazarı doğrulandı; fakat etkinliğin eski takvim sayfasıyla 2026 ajans duyurusu arasında dönem farkı var. Güncel tarihleri detay kaynaktan doğrulamak gerekiyor.
- “Fenty ERP” adı doğrulanamadı. Doğru ad veya URL gelene kadar bu ürünün özellikleri hakkında varsayım yapılmadı.
- “Expo İstanbul”un kesin URL'si ve izlenecek Telegram kanalları verilmedi. İFM doğrulanmış takvim adayıdır; kesin eşleşme değildir.
- Canlı kaynak/sorgu profilleri, erişim koşulları, API modeli/bütçesi ve Telegram chat eşlemesi kullanıcı ortamında ayarlanacak. Araştırma envanteri çalışma ayarı değildir.
- Anlık bildirim; kaynak kontrol aralığı + işleme + teslimat gecikmesine bağlı. Kafka/Prometheus/Grafana kurmak ürünün canlılık hedefi değil.

Belgeler ekip arkadaşlarına iletilebilir. Bu çalışma kapsamında dışarıya mesaj gönderilmedi veya sunucuya dağıtım yapılmadı.
