# Kaynak kapsamı ve Google keşfi

> Güncel etkinlik filtresi, iki saatlik tarama ve altı sayfalık pilot bütçesi için [ETKINLIK_ODAGI_VE_API_KULLANIMI.md](ETKINLIK_ODAGI_VE_API_KULLANIMI.md) belgesine bakın. Aşağıdaki 12 sayfalık/yarım saatlik ayarlar önceki sürüme aittir.

## Önceki kapsam genişletme sürümü

- 50 kaynak pilotunda varsayılan bütçe kaynak başına döngüde 12 URL, derinlik 2. `--pages` ve `--depth` ile değiştirilebilir. Bu bir üst sınırdır; 12 sayfanın tamamının okunacağı garantisi değildir.
- Bağlantılar URL ve bağlantı metnine göre etkinlik, fuar, takvim ve duyuru önceliğiyle sıralanır. Genel iletişim/hakkımızda bağlantıları ve desteklenmeyen dosya türleri ayrılır. Siteye özel selector yoktur.
- Yeni bağlantılar, daha önce okunmuş bağlantılardan önce seçilir. Sonraki derinlikteki detaylara yer bırakılır. Önceden bilinen sayfalar son kontrol zamanına göre dönüşümlü taranır.
- Yönlendirmeler sayfa hakkını tekrar tüketmez; beş yönlendirme sınırı ve domain kontrolleri devam eder.
- Aynı izinli domain kapsamındaki robots.txt yönlendirmeleri, istekler arası bekleme korunarak izlenir. Elde edilen robots kuralları uygulanır. Domain dışına yönlendirme, yasaklanan yollar ve bot korumaları otomatik aşılmaz.
- Birden fazla `article` olan listelerde yalnızca ilk makaleyi alma davranışı düzeltildi.
- Telegram artık Docker servis adı `radar` üzerinden bağlanır; radarın ağ oturumuna bağlı değildir. API portu host üzerinde yayımlanmaz; bearer token zorunludur. Docker dışında varsayılan dinleme adresi loopback kalır.

## Güncelleme

GitHub'a yerel değişiklikler gönderildikten sonra VPS'te:

```bash
git pull --ff-only
bash scripts/vps.sh start --provider mistral --model mistral-small-2603 --sources 50
bash scripts/vps.sh retry-crawls
bash scripts/vps.sh sources
bash scripts/vps.sh status
```

`start` pilot ayarlarını yedekleyip yeniden üretir. Mevcut günlük LLM sınırını korur; özel elle yazılmış profilleri yeniden üretmez. Kaynak başına sayfa hakkı arttığından toplam analiz yükü artabilir. `retry-crawls` yalnız aktif profillerin incelemedeki geçici ağ/5xx ve robots yönlendirme hatalarını bir kez yeniden kuyruğa alır. Yasaklanan yollar, 403 ve belirsiz Telegram teslimleri yeniden denenmez.

## Kaynak raporunu okuma

`sources` bütün aktif profilleri, henüz hiç sayfa okuyamayanlar dahil gösterir:

| Alan | Anlamı |
| --- | --- |
| `pages` | Kaydedilmiş benzersiz URL sayısı; son döngünün istek sayısı değildir |
| `pages_analyzed` | Saklanan sayfa sürümü için tamamlanmış analiz sayısı |
| `last_fetch`, `last_analysis` | Son okuma ve tamamlanmış analiz zamanı |
| `largest_text_chars` | Kaynaktaki en uzun çıkarılmış metin |
| `jobs` | Tarama/analiz/arama için durum ve hata bazında sayılar; eski inceleme kayıtlarını da içerir |
| `items` | Eşleşmiş, belirsiz, geçmiş veya elenmiş kayıt sayıları |
| `notifications` | Bekleyen, gönderilen veya sorunlu bildirimler |

Analiz tamamlanma zamanı bu sürümle kaydedilmeye başlar. Eski analizler geriye dönük başarılı kabul edilmez. Sıfır kayıt bulan tamamlanmış analiz de `pages_analyzed` sayılır; sırf işi `done` olarak kapatmak analiz sayılmaz. `pages > pages_analyzed` olduğunda önce analiz kuyruğu/hatalarına bakın. Eşleşme var ve bildirim bekliyorsa Telegram loguna bakın.

## Google dork keşfini açma

VPS `.env` dosyasına `SERPAPI_API_KEY` ekleyin; anahtarı Git'e koymayın. Ardından:

```bash
bash scripts/vps.sh start --provider mistral --model mistral-small-2603 --sources 50 --google
```

Sekiz sorgu profili eklenir (toplam 58 profil). Google aramaları ayrı bir kalıcı zamanlayıcıyla 24 saatte bir çalışır; bulunan sayfalar yarım saatte bir dönüşümlü kontrol edilir. Her sorgu en fazla ilk 10 organik sonucu alır. Sayfalama yoktur. Normal durumda 30 günde 240 sorgu; tekrarlar ilave istek tüketebilir. Uygulamanın mevcut SerpAPI tavanı günlük 50 çağrıdır ve sağlayıcı kotasının yerine geçmez.

Yeni domainler yalnız `discover_new_domains: true` olan Google profillerinde otomatik keşfe alınır. Sonuç URL'si ve aynı domain içindeki takip edilen bağlantılar kaydedilir. Her gerçek istekte HTTP/HTTPS, genel IP, DNS sabitleme, domain, robots, boyut ve hız kontrolleri uygulanır. Arama başlığı/snippet etkinlik kanıtı sayılmaz: hedef sayfanın metni okunup LLM'e gönderilir. Sosyal medya entegrasyonu eklenmez; oturum gerektiren içeriklere erişim sağlanmaz.

Sorgular `scripts/setup_pilot.rb` içinde tanımlıdır; elle düzenlenen sorgular `start` ile yeniden üretilebilir. `--google` sonraki kurulumlarda korunur. Kapatmak için `--no-google` kullanın. Anahtar eksikse yeni konteynerler başlatılmadan önce ortam kontrolü hata verir; çalışan servisler durdurulmaz.

## Kalan sınırlar

JavaScript tarayıcı, RSS içerik ayrıştırıcısı ve PDF okuyucu eklenmedi. Çok uzun metinler (50 kaynak pilotunda yaklaşık 68.700 karakter) ve 2 MB üzerindeki yanıtlar hâlâ incelemeye ayrılır. Sayfa sıralaması sezgiseldir; bütün etkinliklere ulaşmayı garanti etmez. Farklı URL'lerde aynı etkinlik için tekrar bildirimi hâlâ oluşabilir. LLM hız ve günlük bütçe sınırları sürer; daha çok sayfa eklemek 30 dakikada tam analiz garantisi sağlamaz.

Yerel testler dış API yerine sahte sağlayıcı yanıtları ve gerçek PostgreSQL kullanır. VPS üzerinde gerçek Google/Telegram erişimi ve Docker servisinin yeniden başlamadan sonra bağlantısı dağıtımdan sonra kontrol edilmelidir.
