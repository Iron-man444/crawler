# AWS üzerinde çalışma ve küçük sunucu kapasitesi

24 Eylül 2026. Resmî AWS sayfaları kontrol edildi; kullanıcı hesabı, kalan krediler ve seçilecek bölge görülmedi. Performans değerlendirmeleri mimari tahmindir; uygulama henüz ölçülmedi. AWS kaynağı oluşturulmadı.

## Karar önerisi

Bu Telegram odaklı servis AWS EC2'de çalışabilir. İlk pilot için **Ubuntu Server + 2 vCPU / 2 GiB RAM + API üzerinden LLM** önerilir. Rust/Go servisi, Python botu ve küçük PostgreSQL aynı makinede olabilir. Google keşfi arama API'sine; ağır JavaScript render gerekiyorsa uzaktaki izinli toplama hizmetine verilebilir. API ücretleri AWS sunucu ücretinden ayrıdır.

AWS; Ubuntu, Amazon Linux ve Windows Server gibi sistemleri destekler. [EC2 FAQ](https://aws.amazon.com/ec2/faqs/). Ubuntu bir Linux dağıtımıdır. Bu işte masaüstü kurulmasına ihtiyaç yoktur. Düşük RAM'de Windows/RDP yerine Ubuntu Server tercihimiz, uygulamaya daha fazla kaynak bırakma amaçlı mühendislik önerisidir.

## Makine ve iş yükü

| Makine | Resmî kapasite | Bu proje için değerlendirme |
|---|---|---|
| t3.micro | 2 vCPU, 1 GiB | Çok küçük API tabanlı deneme yapılabilir; aynı makinede PostgreSQL ve botla bellek alanı dar |
| t3.small | 2 vCPU, 2 GiB | x86_64 Ubuntu ile önerilen başlangıç; hesap kredilerinden tüketimi kontrol edilmeli |
| t4g.small | 2 vCPU, 2 GiB | ARM64 Linux ile uygun başlangıç adayı; tüm ikili/paketler ARM64 uyumlu olmalı |
| 4 GiB veya üstü | Seçilen tipe göre | Tarayıcı render ve daha yoğun iş için ek pay; otomatik olarak ücretsiz kabul edilmez |

Donanım kaynakları: [T3 tablosu](https://aws.amazon.com/ec2/instance-types/t3/), [T4g tablosu](https://aws.amazon.com/ec2/instance-types/t4/). T4g önerisi Ubuntu/Linux ARM64 dağıtımı içindir; Windows seçimi için uygun x86_64 EC2 türü/AMI ayrıca seçilir.

| İş | 2 GiB Ubuntu üzerindeki beklenti |
|---|---|
| Rust/Go zamanlayıcı, HTTP istekleri, tag/kelime filtreleri | Düşük hacimde uygun |
| Uzak LLM API çağrıları | Hesaplama sağlayıcıda; yerel kaynak ihtiyacı sınırlı |
| Küçük PostgreSQL + Python Telegram botu | Düşük bağlantı sayısı, kısa transaction ve sınırlı kuyrukla makul pilot |
| Yerel Chromium/Playwright ile birçok sayfa | RAM ve CPU baskısı; ilk profilde çoklu tarayıcı yok |
| Yerel Mistral veya benzeri LLM | 1–2 GiB makineler hedef kalite ve süre için uygun başlangıç değil; küçük model dahi ayrıca benchmark ister |

İlk profil: 1–2 HTTP işi, 1 LLM API isteği, 15–60 dakikalık yapılandırılabilir kontrol; sayfa boyutu ve toplam sayfa sayısı sınırlı. Bu sayılar kapasite garantisi değildir. Site sayısından çok sayfa miktarı, JavaScript ihtiyacı ve kontrol sıklığı belirleyicidir. Derleme/paketleme geliştirici makinesinde veya CI'da yapılır; küçük sunucu hazır çıktıyı çalıştırır.

## CPU kredileri

T3/T4g burstable sınıflardır. İki vCPU, sürekli iki çekirdeği yüzde yüz kullanmanın ücretsiz olduğu anlamına gelmez. `small` boyutlarının taban seviyesi vCPU başına %20'dir; kısa yükselişleri kredi sistemi karşılar. [T3](https://aws.amazon.com/ec2/instance-types/t3/), [T4g](https://aws.amazon.com/ec2/instance-types/t4/).

T3/T4g varsayılan `Unlimited` modunda uzun süre tabanın üzerinde çalışırsa ek CPU kredisi maliyeti oluşabilir. `Standard` ek burst kredi bedeli yerine kredi bitince performansı sınırlar. Kontrol aralığı ve kuyruk gecikmesi buna göre ölçülmeli. [AWS Unlimited açıklaması](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances-unlimited-mode.html). Bu nedenle sürekli yerel LLM veya ağır tarayıcı taraması ücretsiz küçük instance için iyi eşleşme değildir.

## Ücretsiz kullanımın güncel anlamı

Yeni hesaplarda Free Plan en fazla 6 ay veya krediler bitene kadar sürer. Başlangıçta 100 USD, belirtilen aktivitelerle ek en fazla 100 USD kredi verilir; 200 USD'nin tamamı otomatik başlangıç bakiyesi değildir. Free Plan süresiyle kredi son kullanım tarihi ayrı kavramlardır. [AWS Free Tier FAQ](https://aws.amazon.com/free/free-tier-faqs/).

15 Temmuz 2025 öncesi hesapların eski 12 aylık kuralları farklıdır; yeni hesaplar için işaretlenmiş instance listesi de daha geniştir. “Free tier eligible” etiketi, seçilen makinenin süresiz 7/24 ücretsiz olduğu anlamına gelmez. Hesap/bölge ve kalan kredi Launch/Billing ekranlarında kontrol edilmelidir. [EC2 Free Tier dokümanı](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html).

Ayrıca AWS'nin resmî duyurusunda **31 Aralık 2026'ya kadar t4g.small için ayda toplam 750 saat** deneme sunuluyor; mevcut ve yeni hesaplar için belirtilen bölgelerde geçerli. Tek makinenin tam ay çalışması bu saat miktarına sığar. Kampanya yalnızca instance altyapısı içindir; fazla CPU kredisi ve diğer giderleri kendiliğinden kapsamaz. [EC2 T4g deneme koşulları](https://aws.amazon.com/ec2/faqs/), [T4g ürün sayfası](https://aws.amazon.com/ec2/instance-types/t4/). Hesap planındaki diğer süre/erişim koşulları devam eder; bu kampanya Free Plan'ı otomatik uzatma vaadi değildir.

## Toplam maliyet ve pilot doğrulaması

EC2 dışında disk/snapshot, public IPv4, uygunluk sınırlarını aşan veri aktarımı ve varsa Marketplace yazılımı ayrı kalemlerdir. T4g altyapı kampanyası bütün faturayı sıfırlamaz. Public IPv4 standart tarifesi saatte adres başına 0,005 USD'dir; hesaba özel kredi/kapsama son faturayı değiştirebilir. [AWS VPC fiyatları](https://aws.amazon.com/vpc/pricing/). Mistral/başka LLM, SerpAPI ve Firecrawl giderleri ayrıca hesaplanır.

Günlük/aylık harcama bildirimi kurulması önerilir; bildirim kendi başına harcamayı kesen bir sınır değildir. Ücretsiz hesap planı ve ücretli planın sona erme/faturalama davranışları ayrı kontrol edilir. Kalıcı veri için sunucu dışında yedek tutulur; instance'ı kapatmanın diski/snapshot'ı otomatik silmediği hesaba katılır.

Pilot kabulü: 24–48 saat gerçek sınırlı iş yükünde bellek, OOM/restart, CPU kredi dengesi, kuyruk gecikmesi, disk büyümesi ve API maliyeti ölçülür. Veritabanı ve HTTP bağlantıları sınırlandırılır. Bellek daralır veya CPU kredi dengesi sürekli azalırsa önce eşzamanlılık/render azaltılır; yetmezse kapasite artırılır. Bu test yapılmadan “şu kadar siteyi kesin taşır” denmez.

Önerilen başlangıç seçimi: kampanya ve ARM64 uyumu doğrulanırsa **t4g.small + Ubuntu Server ARM64 + API LLM**; x86 ihtiyacı varsa **t3.small + Ubuntu Server x86_64 + API LLM**, hesap kredi tüketimi izlenerek. Eğitim/indirim modülleri ve web bu pilotta yoktur.
