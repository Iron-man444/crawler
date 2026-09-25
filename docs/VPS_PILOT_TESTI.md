# VPS üzerinde web kaynakları → Gemini → Telegram testi

Mevcut `.env` dosyanız korunur. `POSTGRES_PASSWORD`, `RADAR_API_TOKEN`, `GEMINI_API_KEY`, `TELEGRAM_BOT_TOKEN` ve `TELEGRAM_TARGETS` dolu olmalı. `TELEGRAM_TARGETS` örneği: `{"main":"123456789"}`. Botla özel sohbette önce /start gönderin veya botu hedef gruba ekleyin. Yalnız tokenların yazılması chat ID eksikliğini gidermez. Kurulu veritabanının parolasını bu işlem sırasında değiştirmeyin.

## 1. Yerel PowerShell: değişiklikleri gönder

```powershell
git add .gitignore .dockerignore config/settings.pilot.json scripts/setup_pilot.rb test/setup_pilot_test.rb docs/VPS_PILOT_TESTI.md docs/ERP_ETKINLIK_KAYNAKLARI.md arastirma/erp_etkinlik_kaynaklari.json
git commit -m "Add ERP event pilot configuration and VPS test setup"
git push origin main
```

## 2. Ubuntu VPS: güncelle ve pilotu hazırla

Docker Engine ve Compose kurulu olmalı. Komutları sırayla çalıştırın; bir adım hata verirse devam etmeyin.

```bash
cd ~/crawler
git pull --ff-only
sudo docker compose stop telegram radar
sudo docker build -t firsat-radari:pilot .
sudo docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/config:/app/config" firsat-radari:pilot ruby scripts/setup_pilot.rb --model gemini-3.8-flash
sudo docker run --rm -v "$PWD/config:/app/config:ro" firsat-radari:pilot ruby bin/radar validate
sudo docker compose up --build -d --force-recreate
sudo docker compose logs --tail=100 -f radar telegram
```

Model örneği, 24 Eylül 2026 tarihli [Google model yaşam döngüsü listesine](https://ai.google.dev/gemini-api/docs/deprecations) göre `gemini-3.8-flash`. Hesabınızda farklı model kullanıyorsanız `--model` değerini değiştirin. Mevcut settings.json içinde geçerli Gemini modeliniz varsa `--model ...` bölümünü tamamen kaldırabilirsiniz; kurulum onu korur. Modelin hesabınızın kotasında çalıştığı canlı testle anlaşılır.

Kurulum önceki settings.json dosyasını aynı klasöre zaman damgalı yedekler, ardından pilot ayarlarını yazar; yalnız model korunur, eski profiller pilotla değiştirilir. Yedekler Git ve Docker imajından hariçtir. .env okunmaz/değiştirilmez. Kurulum konteynerine API anahtarı verilmez. `validate` yalnız yapılandırmayı doğrular, API bağlantılarını test etmez.

Pilot: MAKTEK etkinlik detayı, TEKNOFEST etkinlik sayfası, TÜSİAD duyuruları. Üç aktif kaynak, kaynak başına bir sayfa, bağlantı derinliği sıfır. Bu ilk test detay linklerinin tümünü dolaşmaz. Diğer yedi kaynak dosyada pasiftir. Sosyal kaynaklar ve SerpAPI kapalı; ilk tarama bildirimi açık; kontrol aralığı altı saat, günlük en fazla 40 LLM çağrısı. Bir sayfa birden fazla LLM çağrısı ve birden fazla bildirim oluşturabilir; bu para veya mesaj sayısı limiti değildir.

## 3. Sonucu incele

Log izlemeyi Ctrl+C ile bırakmak servisleri durdurmaz. İlk işlem için birkaç dakika bekleyin; süre bağlantı, belge boyu, host beklemesi ve API kotasına bağlıdır.

```bash
sudo docker compose ps
sudo docker compose exec radar ruby bin/radar status
sudo docker compose exec radar ruby bin/radar review
```

Başarı: crawl/analyze işleri tamamlanır, ilgili kayıtlar oluşur, notifications içindeki sent sayısı artar ve hedef sohbette başlık/kaynak bağlantısı görülür. Hiç ilgili kayıt çıkmazsa mesaj gelmemesi normaldir; yalnız mesaj gelmemesine bakarak bağlantı arızası sonucuna varmayın.

- `http_401` / `http_403`: review içindeki hosta bakın. Gemini ise anahtar/erişim; kaynak sitesi ise kaynak erişimi araştırılır.
- `http_429`: kota/hız sınırı; bekleme uygulanır. Günlük uygulama sınırı sağlayıcının kotasını kaldırmaz.
- Model erişimi/isteği hatası: model kimliğini ve hesabınızın erişimini kontrol edin; model listesinde bulunması yapılandırılmış çıktı çağrısının başarılı olduğunu kanıtlamaz.
- `document_needs_review_too_long`: sayfa bölüm sınırını aşıyor; bu sayfa tam analiz edilmiş sayılmaz.
- `challenge_page` / `unsupported_content`: kaynak mevcut HTML okuyucuyla okunamıyor.
- `uncertain`: model karar veremediği için gönderilmedi.
- `unknown_delivery`: Telegram teslimi belirsiz; önce sohbeti kontrol edin, kör tekrar göndermeyin.

Çalışan radar varken ayrıca `radar once` başlatmayın; tek worker kilidi vardır. Yeniden başlatmak aynı kayıtları yeniden göndermez ve tarama zamanını otomatik sıfırlamaz. Hata giderildikten sonra review çıktısındaki iş için `ruby bin/radar retry-job ID` kullanılabilir; engellenmiş host gerekiyorsa ayrıca `unblock-host HOST` ile açılır.

Testi durdurmak için verileri silmeden:

```bash
sudo docker compose stop telegram radar
```

## 4. On kaynağa genişlet

İlk test başarılı olduktan sonra:

```bash
sudo docker compose stop telegram radar
sudo docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/config:/app/config" firsat-radari:pilot ruby scripts/setup_pilot.rb --all
sudo docker compose up -d --force-recreate
```

Bu adım on kaynağı açar, kaynak başına üç sayfa ve bir bağlantı derinliği tanımlar. Yeni profiller ilk sonuçlarını bildirir. Önceden taranmış profiller altı saatlik zamanlamalarını koruyabilir. Mevcut profil ayarı değişirse uygulama yeniden değerlendirmeyi sessiz yapabilir; eski kayıtların yeniden gönderilmesi beklenmemeli. Farklı sitelerin aynı etkinliği duyurması hâlâ mükerrer mesaj oluşturabilir.

Genel HTML/JSON-LD okuyucusu kullanılır; siteye özel selector yoktur. PDF ve JS çalıştırma desteği yoktur. Kaynakların koşulları ve robots.txt kuralları kapsamında tarama yapılır. Yerel kurulum testi canlı Gemini, Telegram veya VPS/Docker testinin yerine geçmez.
