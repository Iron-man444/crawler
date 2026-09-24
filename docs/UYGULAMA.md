# Ruby uygulaması — ilk çalışan sürüm

24 Eylül 2026. Ana servis ve hazır Telegram göndericisi Ruby ile yazıldı. Rails veya web arayüzü gerekmiyor. Önceki teknik plan hedef kapsamdır; bu belge mevcut uygulamanın davranışını anlatır.

## Kurulum

Ruby 3.3/3.4 ve PostgreSQL 16+ gerekir. Bu makinede Ruby 3.4 ve PostgreSQL 18 ile test edildi. Windows için [RubyInstaller](https://rubyinstaller.org/downloads/), Linux için sisteminize uygun Ruby kurulumu kullanılabilir. Yerel LLM/GPU gerekmiyor.

```sh
bundle install
```

`config/settings.example.json` dosyasını `config/settings.json` olarak kopyalayın. Örnek profil bilerek pasiftir. Takip edeceğiniz kaynakların erişim şartlarını kontrol edip `seed_urls`, `allowed_domains`, sorgular ve konu açıklamasını ayarlayın; sonra `enabled: true` yapın. Alt domainler izinli domain kapsamındadır. Yeni arama sonuçlarının domainleri otomatik izin almaz; `review` çıktısına düşer.

LLM ayarı:

```json
{
  "provider": "gemini",
  "model": "HESABINIZDA_ERISILEBILEN_MODEL_KIMLIGI",
  "api_key_env": "GEMINI_API_KEY",
  "max_calls_per_day": 100,
  "chunk_chars": 10000,
  "max_chunks": 8
}
```

Mistral için `provider: "mistral"`, `api_key_env: "MISTRAL_API_KEY"` ve hesabınızdaki yapılandırılmış JSON çıktısını destekleyen model kimliğini seçin. Model adını kod değiştirmeden değiştirebilirsiniz. API planları web sohbet aboneliğinden ayrıdır. Sağlayıcı değişiminde sessiz yeniden değerlendirme yapılır; otomatik sağlayıcı fallback yoktur.

Sırlar ortam değişkenlerinden okunur. `.env.example` yalnızca şablondur; yerel Ruby komutları `.env` dosyasını otomatik yüklemez. Docker Compose yükler. Anahtarları depoya veya sohbet mesajına koymayın.

PowerShell örneği (değerleri kendi ortamınızda doldurun):

```powershell
$env:DATABASE_URL = 'postgresql://radar:PASSWORD@127.0.0.1:5432/radar'
$env:RADAR_API_TOKEN = 'EN_AZ_32_KARAKTER_RASTGELE_TOKEN'
$env:GEMINI_API_KEY = 'YOUR_API_KEY'
$env:SERPAPI_API_KEY = 'YOUR_SEARCH_KEY'
$env:TELEGRAM_BOT_TOKEN = 'YOUR_BOT_TOKEN'
$env:TELEGRAM_TARGETS = '{"main":"YOUR_NUMERIC_CHAT_ID"}'
```

Ubuntu'da aynı değişkenleri `export NAME='value'` ile tanımlayın. Rastgele token üretimi: `ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'`. `DATABASE_URL` içindeki özel parola karakterleri URL kodlaması gerektirir. Arama kullanmayacaksanız `search_queries: []` yapın; SerpAPI anahtarı gerekmez.

```sh
ruby bin/radar validate
ruby bin/radar migrate
ruby bin/radar run
```

İkinci terminalde aynı `RADAR_API_TOKEN`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_TARGETS` ile:

```sh
ruby bin/telegram
```

Bot önce kullanıcı tarafından başlatılmış veya hedef gruba eklenmiş olmalıdır. `target_ref` profildeki `main` gibi bir etikettir; sadece `TELEGRAM_TARGETS` içindeki sayısal chat ID'ye gönderilir. Kaynaktan gelen içerik alıcıyı seçemez. Kendi Python botunuzu kullanacaksanız hazır Ruby göndericisini çalıştırmayın; aşağıdaki API sözleşmesini kullanın.

Yerel test araçları bu çalışma sırasında `.tools/` içine kondu; sistem PATH'i değiştirilmedi. Bu makinede `ruby` yerine `.\.tools\rubyinstaller-3.4.10-1-x64\bin\ruby.exe` kullanılabilir. `.tools`, `vendor`, gerçek ayar ve sır dosyaları Git dışında tutulur. Geçici test PostgreSQL'i üretim veritabanı olarak kullanmayın.

## Docker ile çalıştırma

Docker Engine/Compose veya Windows'ta Linux container desteği gerekir. `.env.example` → `.env`, `config/settings.example.json` → `config/settings.json` kopyalayın; yukarıdaki ayarları tamamlayın. `POSTGRES_PASSWORD` için uzun rastgele alfanümerik değer seçin. Varsayılan API portu 8787'yi koruyun.

```sh
docker compose up --build -d
docker compose logs -f radar telegram
docker compose exec radar ruby bin/radar status
docker compose exec radar ruby bin/radar review
```

Veriler `radar_data` volume'ünde kalır. PostgreSQL sadece hostun 127.0.0.1:5432 adresine açılır. Bot API'si container içinde loopback'tedir; internete yayınlanmaz. Telegram container'ı radar container'ının ağını paylaşır. Bu ortamda Docker bulunmadığı için container imajı/Compose çalıştırma testi yapılmadı; yerel Ruby+PostgreSQL testleri yapıldı. Windows Server'da Linux container altyapısı yoksa yerel Ruby kurulumu kullanın.

## Mevcut davranış

- Genel HTML ana metin/bağlantı/JSON-LD çıkarımı ve XML sitemap URL keşfi; siteye özel selector yok. Kaynak başına `max_pages` ve `max_depth` ile sınırlı dolaşım.
- SerpAPI üzerinden Google sorguları. Sorgu başına ilk 10 organik sonuç, bütün profiller için günde en fazla 50 arama çağrısı. İzinli domainler taranır, diğerleri inceleme listesinde tutulur. Snippet gerçek sayfa kanıtı olarak gönderilmez.
- robots.txt kuralları, kalıcı host beklemesi, 429 `Retry-After`, artan yeniden deneme ve 403/challenge sonrası duraklama. Proxy ile engel aşma yapılmaz. robots.txt yönlendirmesi otomatik takip edilmez, inceleme ister.
- Özel IP/metadata adresleri, kullanıcı bilgisi içeren URL'ler, izin dışı yönlendirmeler engellenir. DNS kontrolünden geçen IP'ye bağlantı sabitlenir. İçerik başına 2 MB ve istek başına 60 saniye sınırı vardır.
- Değişmeyen metin yeniden analiz edilmez. Uzun metinler 300 karakter örtüşen bölümlere ayrılır; bölüm sınırını aşan belgeler sessiz kesilmez, incelemeye alınır. Tamamlanan LLM bölümleri kalıcı önbellektedir.
- Gemini/Mistral JSON şeması ve alan kontrolü; modelin kanıt alıntısının metinde birebir bulunması gerekir. Bu kontrol modelin bütün yorumlarını doğrulamaz. Belirsiz kayıtlar `review` içinde saklanır, gönderilmez.
- Türkçe harf normalizasyonu, tam kelime/ifade ANY/ALL, hariç kelime/tag, tür ve konum filtresi. `AI`, `mail` içinde eşleşmez. Education/discount türleri örnek profilde hariçtir.
- İlk profil taraması varsayılan sessizdir. `notify_initial: true` ilk sonuçları da gönderir. Sonraki yeni kayıtlar bildirilir. Var olan aynı başlıklı kaydın tür/tarih/konum değişimi güncelleme bildirimi oluşturur. Özetin farklı yazılması bildirim oluşturmaz.
- Kalıcı işler ve transaction içinde kayıt/olay/outbox. Tek aktif radar worker'ı için PostgreSQL advisory lock. Başlangıç sürümü yatay ölçekleme hedeflemez. Çöken işin lease'i en fazla bir saat içinde yeniden alınır.
- Telegram claim/ack/renew/fail, düz metin ve UTF-16 mesaj boyutu sınırı. Gönderim timeout'u veya teslim lease'i dolması `unknown_delivery` olur; kör tekrar gönderim yapılmaz. ACK tekrarları idempotenttir.

## İşletim ve sorun çözme

```sh
ruby bin/radar status
ruby bin/radar review
ruby bin/radar once
ruby bin/radar retry-job 123
ruby bin/radar unblock-host example.org
ruby bin/radar resolve-delivery DELIVERY_UUID sent
ruby bin/radar resolve-delivery DELIVERY_UUID retry
```

`once` zamanlanmış işleri tek tur işler; host beklemesi nedeniyle bütün kuyruğu bitirmeyebilir. Sürekli çalışma için `run` kullanın. `retry-job` yalnızca incelemeye düşen işi tekrar açar. `unblock-host` sadece erişim sorunu çözüldükten sonra kullanılmalıdır; ilgili işleri de `retry-job` ile açın.

`unknown_delivery` için önce Telegram'ı kontrol edin. Mesaj ulaştıysa `sent`, ulaşmadıysa `retry` seçin. Yanlış `retry` seçimi çift mesaja neden olabilir. Gerçek “tam bir kez” teslim garantisi yoktur.

Kaynak/model/filtre değişiminden sonra servisi yeniden başlatın. Yeni domaini izin listesine eklediğinizde sonraki arama turu onu işleyebilir. Hatalı API anahtarı/kota nedeniyle engellenmiş sağlayıcı hostunu, ayarı düzelttikten sonra açın.

`max_calls_per_day` UTC günündeki bütün LLM istek denemelerini kapsar. Bir belge birden fazla çağrı tüketebilir. Bu bir para harcama limiti değildir; sağlayıcı panelinde bütçeyi ayrıca sınırlandırın. SerpAPI ve LLM kullanımları ayrı sayaçlardır.

## Bot API sözleşmesi

Tüm uçlar `Authorization: Bearer RADAR_API_TOKEN` ister. Varsayılan adres `http://127.0.0.1:8787`.

| İstek | Davranış |
|---|---|
| `GET /api/v1/status` | İş, bildirim, kayıt kararı ve günlük kullanım sayıları |
| `POST /api/v1/notification-jobs/claim` | Bir işi 5 dakika kiralar; boş kuyruk 204 |
| `POST /api/v1/notification-jobs/{id}/ack` | `claim_token`, `message_id` ile teslim onayı |
| `POST /api/v1/notification-jobs/{id}/renew` | `claim_token` ile lease uzatma |
| `POST /api/v1/notification-jobs/{id}/fail` | `claim_token`, `type`, isteğe bağlı `retry_after` |

Claim: `delivery_id`, `claim_token`, `lease_until`, `target_ref`, `payload`. Payload içinde `kind`, `item`, `url`, `checked_at`, `evidence_status` bulunur. `type`: `transient`, `permanent`, `unknown_delivery`. Geçersiz/süresi dolmuş token 409. Botun DB erişimine ihtiyacı yoktur.

## Testler ve açık sınırlar

```sh
bundle exec ruby scripts/test.rb
```

DB testleri için ayrı, boş test veritabanı adresini `RADAR_TEST_DATABASE_URL` ile verin. Testler rastgele isimli kendi şemalarını oluşturup sonunda kaldırır. Ortam değişkeni yoksa DB testleri skip edilir. Gerçek sağlayıcı ve Telegram istekleri testlerde kullanılmaz.

İlk sürümde JavaScript render/Firecrawl, yerel LLM, Telegram kanalından veri toplama, kaynaklar arası anlamsal birleştirme, otomatik iptal/son tarih alarmı, toplu bildirim özeti ve otomatik saklama temizliği yoktur. Başlığı değişen kayıt yeni öğe sayılabilir; aynı bilgi farklı URL/profil üzerinden gelirse ayrı bildirim olabilir. Liste sayfasında alınan kaydın linki o liste sayfasıdır. Bütçe içindeki tarama tüm siteyi kapsamaz; bilinen detay sayfalarına bütçenin en fazla yarısı ayrılıp yeni bağlantılara yer bırakılır. JS ile yüklenen veya giriş isteyen içerik için ek adaptör gerekir.

Yerel doğrulama: **31 test, 119 assertion, 0 hata, 0 atlanan test**. PostgreSQL transaction geri alma, kalıcı işler, ilk tarama sessizliği, önbellek, yeni bilgi, teslim lease'i/ACK, HTTP API, erişim engeli, yönlendirme ve Türkçe metin korunması dahil. Docker ve GitHub Actions yapılandırmaları eklendi; bu ortamda çalıştırılmadı.

Gerçek sağlayıcı kalitesi, model erişimi, site erişimi, VPS kapasitesi ve Telegram teslimi henüz canlı test edilmedi. API anahtarları ve kaynaklar hazırlandığında küçük bir pilotla ölçülmelidir. Web/TUI, eğitim/indirim, CRM/ERP ve blog bu sürüme dahil değildir.

Dayanak API belgeleri: [Gemini yapılandırılmış çıktı](https://ai.google.dev/gemini-api/docs/structured-output), [Mistral Chat API](https://docs.mistral.ai/api/endpoint/chat), [SerpAPI](https://serpapi.com/search-api), [Telegram Bot API](https://core.telegram.org/bots/api#sendmessage).
