# Sunucuya ilk aktarım ve kısa test

Durum: SSH bağlantı bilgisi bekleniyor. Bu belge ve test paketi hazırlandı; AWS sunucusuna henüz bağlanılmadı.

## Bağlantı kontrolü

SSH için public IP/DNS, kullanıcı adı ve özel anahtarın yerel dosya yolu gerekir. Ubuntu AMI'de kullanıcı çoğunlukla `ubuntu` olur. Özel anahtarın içeriği paylaşılmaz veya uygulama paketine eklenmez. İlk SSH bağlantısında sunucu host anahtarı parmak izi doğrulanır.

Sunucuda önce işletim sistemi, CPU/RAM/disk, Docker/Compose varlığı ve mevcut servisler kontrol edilir. Mevcut uygulama/veriler değiştirilmez. Uygulama kullanıcının ev dizininde ayrı `firsat-radari` klasörüne aktarılabilir.

## Anahtarsız kısa test

Docker ve Compose varsa proje klasöründe:

```sh
docker compose -p radar-smoke -f compose.smoke.yaml up --build --abort-on-container-exit --exit-code-from test
docker compose -p radar-smoke -f compose.smoke.yaml down --volumes
```

`radar-smoke` bu teste ayrılmış Compose proje adıdır; aynı isimde mevcut kurulum varsa farklı isim seçin. Test veritabanı dışarı port açmaz. Kalıcı uygulama verileri kullanılmaz. Testler gerçek Gemini/Mistral/SerpAPI veya Telegram çağrısı yapmaz. Docker imajları ve Ruby paketleri ilk kurulumda indirilir.

Docker yoksa işletim sistemi belirlendikten sonra uygun kurulum yapılır veya Ruby/PostgreSQL doğrudan kurulur. Küçük makinede ilk imaj derlemesi günlük çalışmadan daha fazla CPU/RAM kullanabilir.

## Canlı pilot

Kısa test başarılı olduktan sonra [uygulama belgesine](UYGULAMA.md) göre sunucuda `.env` ve `config/settings.json` hazırlanır. LLM anahtarı/modeli, varsa SerpAPI anahtarı, Telegram token/chat eşlemesi ve en az bir aktif kaynak gerekir. İlk deneme az sayıda sayfayla yapılır. Bu bilgiler henüz sağlanmadıysa yalnızca altyapı/test kurulumu tamamlanır.

## GitHub ile güncelleme

Repo varsayılan olarak private seçilir. Kaynak kodu ve örnek ayarlar sürümlenir; `.env`, gerçek ayarlar, SSH anahtarları, veritabanı ve `.tools/vendor` dosyaları yüklenmez. Sunucu için yalnızca ilgili repoya erişen salt okunur deploy key kullanılabilir.

İlk bağlantı kurulduktan sonra güncelleme akışı: değişiklik → testler → GitHub'a push → sunucuda seçilen sürümü çekme → imajı yeniden oluşturma → servis sağlığı kontrolü. GitHub'a push etmek tek başına sunucuyu otomatik güncellemez. Otomatik dağıtım ayrıca kurulmalıdır; şu anda aktif değildir.
