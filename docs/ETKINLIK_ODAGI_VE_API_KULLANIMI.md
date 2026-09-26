# Buluşma odaklı bildirim ve API kullanımı

Bu sürüm önceki geniş ticari fırsat profilinin yerini alır. Kullanıcının istediği şey şirketlere yararlı her bilgi değil, insanlarla tanışabileceği profesyonel etkinliklerdir.

## Gönderilecek kayıtlar

Fuar, konferans, kongre, zirve, networking, B2B görüşmeleri, mesleki/iş buluşmaları ve teknoloji festivalleri. ERP kelimesi zorunlu değildir; sektör kapsamı geniştir. Somut buluşma kanıtı ve yıl içeren bugüne veya geleceğe ait tarih gerekir. Tarihi bilinmeyen kayıt `missing_event_date` olarak tutulur, gönderilmez. Bu tercih bazı gerçek fakat tarihi eksik etkinlikleri kaçırabilir.

Gümrük Müşavirleri için Vekaleten Belge Talebi, belge satışı, mevzuat, aidat, ihale ve idari başvurular etkinlik değildir. Eğitim, sertifika ve indirimler de kapsam dışıdır. Gerçek konferans duyurusu `event` sayılır; bütün duyurular toptan yasaklanmaz. Kaynakta kanıtı olmayan buluşma veya tarih üretilmemelidir.

## Çağrı azaltma

- LLM öncesi etkinlik ifadeleri için yerel kontrol vardır. Etkinlik işareti taşımayan sayfa API çağrısı kullanmaz. Uzun sayfalarda yalnız aday parçalar ve sınır bağlamını korumak için komşu parçalar analiz edilir. Bu sezgisel kontrol bütün ifade biçimlerini tanıyamaz.
- Önbellek imzasından günlük çağrı sınırı, kimlik bilgisi adı, profil ID'si, kaynak URL'si, sayfa hakkı, tarama sıklığı ve Telegram hedefi çıkarıldı. Model/politika/analiz biçimi değişiklikleri hâlâ önbelleği geçersiz kılar.
- Aynı metin, model ve analiz politikası farklı profillerde ortak önbellekten okunabilir. Farklı HTML'den farklı metin çıkan benzer sayfalar otomatik aynı kabul edilmez.
- 50 kaynak pilotu artık iki saatte bir, altı URL ve iki bağlantı derinliği kullanır. İstenirse `--interval` ve `--pages` ile değiştirilir. Google keşfi günlük kalır; Google profilleri bilinen sayfaları iki saatte bir dönüşümlü kontrol eder.
- Şema, kanıt doğrulama veya eksik çıktı hataları en fazla iki iş denemesinden sonra incelemeye ayrılır. Sağlayıcı 429/503 hatalarının mevcut geri çekilme davranışı sürer.
- Günlük LLM çağrı tavanı korunur. Tavan maliyet veya token limiti değildir. Gerçek çağrı azalması VPS'teki sonraki ölçümlerle görülecektir; sabit yüzde tasarruf garantisi yoktur.

## Bildirim kuyruğu

Gönderimden önce güncel profil yeniden uygulanır. Eski kurallarla kuyruğa giren uygunsuz kayıtlar silinmez; `suppressed` durumuna alınır. Daha önce gönderilmiş Telegram mesajları silinmez. Gönderilmiş, gönderilmekte olan veya teslimi belirsiz aynı başlık/tarih/konum kaydı aynı hedef için tekrar gönderilmez. Geçici hatada aynı teslim kaydı yeniden denenebilir. Başlığı farklı yazılmış aynı etkinlik hâlâ tekrar görünebilir; farklı tarih/konum ayrı kayıt sayılır.

## VPS güncellemesi

Yerel değişiklikleri GitHub'a gönderdikten sonra:

```bash
git pull --ff-only
bash scripts/vps.sh start --provider mistral --model mistral-small-2603 --sources 50
bash scripts/vps.sh audit
bash scripts/vps.sh status
```

`start` pilot ayarlarını yedekleyip yeniden üretir. `.env` ve grup ID'si korunur. Google daha önce açıksa açık kalır. Kural değişikliği nedeniyle ilk tur bir defalık yeniden analiz gerekebilir; mevcut API bütçesi geçerlidir.

`audit` son 50 bildirim kaydının başlığını, kaynağını, türünü, nedenini ve gönderim durumunu gösterir. Bunlar uygulamanın kayıtlarıdır; Telegram geçmişinin doğrudan okunması değildir. Ayrıca son 24 saatin çağrılarını sağlayıcı/model/profil/sonuç bazında ve en fazla çağrı kullanan sayfalar bazında listeler. Kayıtlar bu sürümden itibaren tutulur, önceki 1.200 çağrıya geriye dönük kaynak dağılımı üretilemez. Kaynak karakter sayısı token/fatura tutarı değildir; talimat ve şema karakterleri bu sayaca dahil değildir.

Bir uygulama çağrısı bir Telegram mesajı değildir: tek sayfa birden fazla parça isteği kullanabilir, bazı istekler başarısız olabilir veya hiç uygun etkinlik çıkaramayabilir. Sağlayıcı panelindeki toplamın bu uygulamanın çağrılarıyla eşleşmesi ayrıca doğrulanmalıdır.
