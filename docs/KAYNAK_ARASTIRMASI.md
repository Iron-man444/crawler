# Türkiye etkinlik ve fırsat kaynakları

> Tarihsel araştırma: buradaki 24 kaynak güncel aktif liste değildir. Son kapsam sabit site + Google sorgusu ile farklı bilgi türlerini keşfetme, yerel/API LLM analizi ve Telegram aktarımıdır; web ertelendi. [Güncel görev dokümanı](TEKNIK_GOREV_DOKUMANI.md) ve [aday listesi](../arastirma/firsat_radari_kaynaklari.json) esas alınmalıdır.

Araştırma tarihi: 24 Eylül 2026. Kapsam: Türkiye geneli, tüm sektörlere açık kaynak keşfi. Bu bir başlangıç envanteridir; bütün Türkiye etkinlik ve ilanlarının bulunduğu iddiası taşımaz.

## 1. Araştırma yöntemi ve sonuç

24 kaynak kaydı; resmî web sayfaları ve resmî alan adlarına ait arama sonuçları üzerinden incelendi. Sayfa içeriği okunabilenlerle yalnızca arama indeksinde doğrulananlar ayrı işaretlendi. Bu çalışma otomatik scraping, kullanıcı hesabıyla giriş veya API entegrasyon testi içermiyor. Arama indeksinde görülen içerik yayından kalkmış ya da gecikmeli olabilir.

Öncelikler ürün önerisidir: P0 = ilk entegrasyon araştırması; P1 = ikinci dalga; P2 = erişim/izin/dinamik içerik incelemesi gerektiren kaynak. P0 olması, kaynağın API'si veya otomatik erişim izni doğrulanmış demek değildir. Envanterde bu iki durumun tamamı şimdilik `not_verified`, otomatik toplama ise kapalıdır.

Makine tarafından kullanılabilir eş kayıt: [kaynaklar.json](../arastirma/kaynaklar.json). Her kayıt; domain, giriş URL'si, kapsam, kanıt bağlantısı, kontrol tarihi, erişim durumu, gözlenen etiketler ve önerilen arama sözcüklerini içerir. Domainler erişim güvenliği için host düzeyindedir; ana alan adı ve alt alan adları gerektiğinde ayrıca gruplandırılmalıdır.

## 2. Kaynak envanteri

| ID | Platform / kanıt bağlantısı | Domain / host | Ana tür | Kapsam | Öncelik | Doğrulama |
|---|---|---|---|---|---|---|
| S01 | [TOBB Fuar Takvimi](https://fuarlar.tobb.org.tr/FuarTakvimi) | `fuarlar.tobb.org.tr` | etkinlik | Türkiye / çok sektör | P0 | Sayfa okundu |
| S02 | [TÜYAP Fuar Arama](https://tuyap.com.tr/fuar-arama) | `tuyap.com.tr` | etkinlik | Türkiye / sanayi, gıda, tarım, kitap ve diğer fuarlar | P1 | Resmî arama indeksi |
| S03 | [İstanbul Fuar Merkezi](https://ifm.com.tr/tr/ifm-fuar-takvimi) | `ifm.com.tr` | etkinlik | İstanbul / çok sektör; ulusal katılım | P1 | Resmî arama indeksi |
| S04 | [Biletino](https://biletino.com/tr/turkiye/) | `biletino.com` | etkinlik | Türkiye / kültür, eğitim, sosyal etkinlik | P0 | Sayfa okundu |
| S05 | [Biletinial](https://biletinial.com/tr-tr) | `biletinial.com` | etkinlik | Türkiye / kültür ve sahne etkinlikleri | P1 | Sayfa okundu |
| S06 | [Biletix](https://www.biletix.com/) | `biletix.com` | etkinlik | Türkiye / kültür, spor ve sanat | P2 | Sınırlı içerik |
| S07 | [Kommunity](https://kommunity.com/search) | `kommunity.com` | etkinlik | Türkiye filtresi / topluluk ve mesleki buluşmalar | P1 | Resmî arama indeksi |
| S08 | [TechAnkara Proje Pazarı](https://www.ankaraprojepazari.com/takvim/) | `ankaraprojepazari.com` | etkinlik | Ankara / girişimcilik ve çok sektörlü teknoloji | P1 | Sayfa okundu; eski dönem |
| S09 | [TechAnkara Girişimcilik Portalı](https://girisimci.ankaraka.org.tr/tr) | `girisimci.ankaraka.org.tr` | destek_cagrisi | Ankara / girişimcilik | P1 | Resmî arama indeksi |
| S10 | [DEİK Etkinlikler](https://www.deik.org.tr/etkinlikler) | `deik.org.tr` | etkinlik | Türkiye bağlantılı / dış ticaret ve çok sektör | P0 | Sayfa okundu |
| S11 | [İstanbul Ticaret Odası Etkinlikler](https://ito.org.tr/tr/etkinlikler/) | `ito.org.tr` | etkinlik | İstanbul ve çevrim içi / çok sektör | P0 | Resmî arama indeksi |
| S12 | [TİM Duyurular](https://www.tim.org.tr/tr/duyurular) | `tim.org.tr` | ticari_teklif | Türkiye bağlantılı / ihracat ve çok sektör | P1 | Resmî arama indeksi |
| S13 | [Enterprise Europe Network](https://een.ec.europa.eu/partnering-opportunities) | `een.ec.europa.eu` | ortaklik | Uluslararası; Türkiye'ye uygun ilanlar / çok sektör | P1 | Resmî arama indeksi |
| S14 | [İTO Yan Sanayi Borsası](https://yansanayi.ito.org.tr/) | `yansanayi.ito.org.tr` | ortaklik | Türkiye bağlantılı / sanayi ve tedarik | P0 | Resmî arama indeksi |
| S15 | [Ticaret Bakanlığı Dış Talepler Bülteni](https://distalep.ticaret.gov.tr/giris/) | `distalep.ticaret.gov.tr` | ticari_teklif | Türkiye ihracatçıları / ürün, hizmet ve uluslararası ihale | P2 | Giriş ekranı |
| S16 | [EKAP İhale Arama](https://ekap.kik.gov.tr/EKAP/Ortak/IhaleArama/index.html) | `ekap.kik.gov.tr` | ticari_teklif | Türkiye / kamu alımları, çok sektör | P2 | Yeni ekrana yönlendirme |
| S17 | [Kariyer.net İş İlanları](https://www.kariyer.net/is-ilanlari) | `kariyer.net` | is_ilani | Türkiye / çok sektör | P0 | Sayfa okundu |
| S18 | [Yenibiriş İş İlanları](https://www.yenibiris.com/is-ilanlari) | `yenibiris.com` | is_ilani | Türkiye / çok sektör | P1 | Sayfa okundu |
| S19 | [İŞKUR](https://www.iskur.gov.tr/) | `iskur.gov.tr` | is_ilani | Türkiye / çok sektör | P0 | Sayfa okundu |
| S20 | [KOSGEB Duyurular](https://www.kosgeb.gov.tr/site/tr/genel/liste/2/basin-ve-duyurular?Page=1) | `kosgeb.gov.tr` | destek_cagrisi | Türkiye / KOBİ ve program bazlı sektörler | P1 | Sayfa okundu |
| S21 | [TÜBİTAK](https://tubitak.gov.tr/tr) | `tubitak.gov.tr` | destek_cagrisi | Türkiye / Ar-Ge, bilim ve sektörler arası programlar | P1 | Resmî arama indeksi |
| S22 | [StartupCentrum](https://startupcentrum.com/) | `startupcentrum.com` | ortaklik | Türkiye filtresi / girişimler ve yetenek | P1 | Sayfa okundu |
| S23 | [ODTÜ TEKNOKENT](https://www.odtuteknokent.com.tr/) | `odtuteknokent.com.tr` | etkinlik | Ankara ve program bazlı diğer konumlar / teknoloji | P1 | Resmî arama indeksi |
| S24 | [Türkiye Özel Okullar Derneği (TÖZOK)](https://www.tozok.org.tr/etkinlik-takvimi) | `tozok.org.tr` | etkinlik | Türkiye / eğitim | P1 | Resmî arama indeksi |

Türler bir kaynağı tek içerik sınıfına hapsetmez; örneğin bir oda sayfasında hem etkinlik hem ticari çağrı olabilir. Sınıflandırma her kayıt için yeniden yapılmalıdır. EEN gibi uluslararası kaynaklarda Türkiye'den katılım veya iş birliği uygunluğu ayrıca filtrelenmelidir.

## 3. Kaynak bazında kullanım notları

### S01 — TOBB Fuar Takvimi

Başlangıç/bitiş, konu, şehir, düzenleyici ve web alanları var; Excel dışa aktarımı görünüyor. [Kaynak](https://fuarlar.tobb.org.tr/FuarTakvimi).

**Önerilen kullanım:** İzinli dosya aktarımı veya sayfa adaptörü değerlendirilecek. **Arama sözcükleri (öneri):** fuar, sektörel fuar, B2B.

### S02 — TÜYAP Fuar Arama

Resmî fuar arama ve takvim sayfası indekslendi. [Kaynak](https://tuyap.com.tr/fuar-arama).

**Önerilen kullanım:** TOBB kaydını organizatör ayrıntısıyla zenginleştir; tek etkinliğe bağla. **Arama sözcükleri (öneri):** fuar, imalat, tarım, gıda.

### S03 — İstanbul Fuar Merkezi

Takvimde organizatör, etkinlik adı ve tarih listeleniyor. [Kaynak](https://ifm.com.tr/tr/ifm-fuar-takvimi).

**Önerilen kullanım:** Ay sınırını geçen tarih aralıklarını detay sayfasından doğrula. **Arama sözcükleri (öneri):** fuar, mobilya, reklam, mücevher.

### S04 — Biletino

Kategori, konum ve tarih araması; şehir ve etkinlik listeleri görüldü. [Kaynak](https://biletino.com/tr/turkiye/).

**Önerilen kullanım:** Otomatik toplama hakkı teyit edilecek; başlangıçta kaynak keşfi. **Arama sözcükleri (öneri):** etkinlik, atölye, festival, networking.

### S05 — Biletinial

Etkinlik liste ve bilet bağlantıları görüldü. [Kaynak](https://biletinial.com/tr-tr).

**Önerilen kullanım:** Kategori/şehir detayları kaynak bazında eşlenecek. **Arama sözcükleri (öneri):** tiyatro, konser, sinema, kültür sanat.

### S06 — Biletix

Başlık doğrulandı; araştırma aracına ayrıntılı liste gelmedi. [Kaynak](https://www.biletix.com/).

**Önerilen kullanım:** Dinamik erişim incelemesi gerekiyor; otomasyon hazır kabul edilmez. **Arama sözcükleri (öneri):** konser, spor, sanat, müze.

### S07 — Kommunity

Arama sayfası ve Ankara topluluğu indekslendi; doğrudan açma başarısız. [Kaynak](https://kommunity.com/search).

**Önerilen kullanım:** Topluluk/organizatör üzerinden keşif; API/izin incelemesi bekliyor. **Arama sözcükleri (öneri):** topluluk, meetup, workshop, networking.

### S08 — TechAnkara Proje Pazarı

Takvim 2024 döneminde; 2026 için ajansın ayrı duyurusu esas alınmalı. [Kaynak](https://www.ankaraprojepazari.com/takvim/).

**Önerilen kullanım:** Yıl/dönem, proje başvurusu ve ziyaretçi katılımı ayrı değerlendirilecek. **Arama sözcükleri (öneri):** TechAnkara, proje pazarı, yatırımcı, girişimcilik.

### S09 — TechAnkara Girişimcilik Portalı

2026 Proje Pazarı başvuru duyurusu indekslendi. [Kaynak](https://girisimci.ankaraka.org.tr/tr).

**Önerilen kullanım:** Ajans kaydıyla eşle; başvuru hesabını otomatik kullanma. **Arama sözcükleri (öneri):** hızlandırıcı, girişimcilik, başvuru.

### S10 — DEİK Etkinlikler

İş konseyi yapısı, sektörel başlıklar ve etkinlik sayfası doğrulandı. [Kaynak](https://www.deik.org.tr/etkinlikler).

**Önerilen kullanım:** Geçmiş etkinlik haberini yaklaşan iş forumundan ayır; üyelik koşulunu sakla. **Arama sözcükleri (öneri):** iş forumu, ticaret heyeti, B2B, iş birliği.

### S11 — İstanbul Ticaret Odası Etkinlikler

Tarih/saat, kayıt bilgisi ve başvurusu tamamlanmış etkinlikler indekslendi. [Kaynak](https://ito.org.tr/tr/etkinlikler/).

**Önerilen kullanım:** Etkinlik tarihi ile kayıt durumu için ayrı alanlar kullan. **Arama sözcükleri (öneri):** seminer, tedarikçi günü, eğitim, iş geliştirme.

### S12 — TİM Duyurular

Resmî listede fuar ve ticaret içerikleri görüldü. [Kaynak](https://www.tim.org.tr/tr/duyurular).

**Önerilen kullanım:** Her duyuru fırsat değildir; mevzuat/haber ile çağrıyı ayır. **Arama sözcükleri (öneri):** ihracat, ticaret heyeti, alım heyeti, fuar.

### S13 — Enterprise Europe Network

Ortaklık fırsatları ve Business Offer ilanları indekslendi; doğrudan açma başarısız. [Kaynak](https://een.ec.europa.eu/partnering-opportunities).

**Önerilen kullanım:** Türkiye uygunluğu ilan bazında incelenir. **Arama sözcükleri (öneri):** technology offer, technology request, business offer, research partner.

### S14 — İTO Yan Sanayi Borsası

Resmî sayfa tedarikçi günleri ve talep eşleştirme hizmetini anlatıyor. [Kaynak](https://yansanayi.ito.org.tr/).

**Önerilen kullanım:** Açık etkinliklerle üyeye özel eşleştirme verisini ayır. **Arama sözcükleri (öneri):** tedarikçi, yan sanayi, talep eşleştirme, B2B.

### S15 — Ticaret Bakanlığı Dış Talepler Bülteni

Resmî giriş ekranı ve Bakanlığın içerik açıklaması bulundu. [Kaynak](https://distalep.ticaret.gov.tr/giris/).

**Önerilen kullanım:** Hesap/kullanım yetkisi olmadan toplama yapılmaz; ilk aşama manuel kayıt. **Arama sözcükleri (öneri):** alım talebi, hizmet talebi, ihracat, ihale.

### S16 — EKAP İhale Arama

Eski sayfa yeni arama ekranına yönlendirme bildiriyor. [Kaynak](https://ekap.kik.gov.tr/EKAP/Ortak/IhaleArama/index.html).

**Önerilen kullanım:** Aktif ekranı ve resmî erişimi yeniden doğrula; ilk sürümde manuel bağlantı. **Arama sözcükleri (öneri):** ihale, mal alımı, hizmet alımı, yapım işi.

### S17 — Kariyer.net İş İlanları

Resmî iş ilanı listeleme sayfası okunabildi. [Kaynak](https://www.kariyer.net/is-ilanlari).

**Önerilen kullanım:** İzinli feed/entegrasyon veya manuel kayıt; işe alımı ticari tekliften ayır. **Arama sözcükleri (öneri):** iş ilanı, tam zamanlı, uzaktan, staj.

### S18 — Yenibiriş İş İlanları

Resmî iş ilanı liste sayfası okunabildi. [Kaynak](https://www.yenibiris.com/is-ilanlari).

**Önerilen kullanım:** İlan kimliği ve kapanış bilgisi üzerinden takip. **Arama sözcükleri (öneri):** iş ilanı, kariyer, personel.

### S19 — İŞKUR

İş arama alanında meslek ve şehir seçimi mevcut. [Kaynak](https://www.iskur.gov.tr/).

**Önerilen kullanım:** İlan detayı erişimi ve hesap ihtiyacı ayrı incelenir. **Arama sözcükleri (öneri):** iş ilanı, meslek, istihdam.

### S20 — KOSGEB Duyurular

Resmî duyuru listesi doğrulandı. [Kaynak](https://www.kosgeb.gov.tr/site/tr/genel/liste/2/basin-ve-duyurular?Page=1).

**Önerilen kullanım:** Uygunluk ve son başvuru tarihini kaynak belgesiyle doğrula; haberleri ayır. **Arama sözcükleri (öneri):** destek çağrısı, KOBİ, girişimci, başvuru.

### S21 — TÜBİTAK

Çağrı ve süre uzatımı duyuruları indekslendi. [Kaynak](https://tubitak.gov.tr/tr).

**Önerilen kullanım:** Çağrı numarası, kapanış sürümü ve program şartlarıyla tekilleştir. **Arama sözcükleri (öneri):** Ar-Ge, çağrı, konsorsiyum, proje ortağı.

### S22 — StartupCentrum

Resmî sayfa girişim, iş ilanı, yatırımcı, kuluçka ve hızlandırıcılardan söz ediyor. [Kaynak](https://startupcentrum.com/).

**Önerilen kullanım:** Açık içerik ile profil/üyelik alanlarını ayır. **Arama sözcükleri (öneri):** kurucu ortak, startup, yatırımcı, hızlandırıcı.

### S23 — ODTÜ TEKNOKENT

Resmî program ve ekosistem etkinliği haberleri indekslendi. [Kaynak](https://www.odtuteknokent.com.tr/).

**Önerilen kullanım:** Duyuru tarihini etkinlik tarihi sanma; gerçekleşenleri arşive al. **Arama sözcükleri (öneri):** teknokent, Ar-Ge, teknoloji, girişimcilik.

### S24 — Türkiye Özel Okullar Derneği (TÖZOK)

Derneğin etkinlik takvimi resmî arama sonucunda doğrulandı. [Kaynak](https://www.tozok.org.tr/etkinlik-takvimi).

**Önerilen kullanım:** Eğitim sektörü dikey kaynağı; tarih/katılım koşulunu detaydan doğrula. **Arama sözcükleri (öneri):** eğitim, özel okul, sempozyum, seminer.

## 4. Gerçekten gözlenen etiketler

Aşağıdakiler kaynakta görülen adlardır; önerilmiş hashtaglerle karıştırılmamalıdır.

| Kaynak | Gözlenen değerler | Kanıtın niteliği |
|---|---|---|
| TechAnkara / Ankara Kalkınma Ajansı | #TechAnkara, #ProjePazarı, #Girişimcilik, #İnovasyon, #Networking | [Kurum hesabının gönderisinin arama indeksi](https://tr.linkedin.com/posts/ankara-development-agency_stb-kagm-ankarakalk%C4%B1nmaajans%C4%B1-activity-7467145333249286144-phGa) |
| DEİK | #İşimizTicariDiplomasi | [Etkinlik sayfasında görülen kurumsal hashtag](https://www.deik.org.tr/etkinlikler) |
| TOBB | Uluslararası İhtisas | [Kaynakta fuar türü; hashtag değil](https://fuarlar.tobb.org.tr/FuarTakvimi) |
| Biletino | Canlı Konserler; Stand-Up/Komedi Gösterileri | [Sayfa bölüm adları; hashtag değil](https://biletino.com/tr/turkiye/) |
| EEN | Business Offer | [Resmî arama indeksindeki ilan türü; hashtag değil](https://een.ec.europa.eu/partnering-opportunities) |

Bu başlangıçta 6 hashtag ve 4 kaynak etiketi/bölüm adı elde edildi. Diğer kaynaklarda etiket alanı boş bırakıldı; etiket olmadığı anlamına gelmez. Sosyal platform hashtag araması ayrı bir keşif kanalıdır; hashtag bulunması sosyal hesap içeriğini otomatik toplamaya yetki vermez.

## 5. Önerilen sektör ve sorgu sözlüğü

Aşağıdaki bütün değerler araştırmacı önerisidir; kaynaktan gözlenmiş hashtag veya resmî sektör sınıflandırması değildir. Ürün birden fazla sektör seçimini ve “diğer/sınıflandırılmadı” durumunu desteklemelidir.

| Sektör grubu | Arama sözcükleri | Önerilen hashtag varyantları | Kaynak başlangıcı |
|---|---|---|---|
| Tarım, gıda, hayvancılık | tarım fuarı, gıda, agrotech, tedarikçi | #Tarım, #Gıda, #AgriTech | S01, S02, S12 |
| Sanayi, makine, otomotiv | imalat, makine, otomotiv, yan sanayi | #Sanayi, #İmalat, #Otomotiv | S01, S02, S14 |
| Tekstil, moda, tasarım | tekstil, hazır giyim, tasarım | #Tekstil, #Moda, #Tasarım | S01, S03, S12 |
| İnşaat, gayrimenkul | yapı, inşaat, gayrimenkul, akıllı bina | #İnşaat, #Gayrimenkul | S01, S03, S11 |
| Enerji, çevre | enerji, güneş, dönüşüm, sürdürülebilirlik | #Enerji, #Sürdürülebilirlik | S01, S10, S13 |
| Sağlık, medikal | sağlık, medikal, biyoteknoloji | #Sağlık, #Medikal | S01, S13, S21 |
| Teknoloji, yazılım | yazılım, yapay zeka, siber güvenlik | #Yazılım, #YapayZeka | S07, S08, S23 |
| Eğitim, akademi | eğitim, sempozyum, kongre, araştırma | #Eğitim, #Kongre | S11, S21, S24 |
| Turizm, konaklama, gastronomi | turizm, otel, gastronomi | #Turizm, #Gastronomi | S01, S04, S12 |
| Lojistik, ulaşım | lojistik, taşımacılık, tedarik zinciri | #Lojistik, #TedarikZinciri | S01, S10, S14 |
| Finans, sigorta | finans, sigorta, fintech | #Finans, #FinTech | S10, S11, S22 |
| Perakende, e-ticaret | perakende, e-ticaret, bayi | #Perakende, #ETicaret | S01, S12, S15 |
| Kültür, sanat, spor | konser, tiyatro, festival, spor | #KültürSanat, #Festival, #Spor | S04, S05, S06 |
| Medya, reklam, profesyonel hizmet | reklam, medya, danışmanlık, hizmet alımı | #Reklam, #Medya, #Danışmanlık | S03, S11, S16 |
| Kamu ve sivil toplum | ihale, proje çağrısı, sosyal girişim | #İhale, #ProjeÇağrısı | S09, S16, S20 |
| Sektörden bağımsız işe alım | iş ilanı, kariyer, staj, uzaktan çalışma | #İşİlanı, #Kariyer, #Hiring | S17, S18, S19 |

Türkçe asıl yazım korunur; arama için `iş birliği/isbirligi`, `girişimcilik/girisimcilik` gibi normalleştirilmiş karşılıklar ayrıca üretilir. Konum etiketleri 81 ili kapsayacak şekilde genişletilir; şirket merkezinin bulunduğu şehir otomatik olarak etkinlik şehri kabul edilmez.

Örnek keşif sorguları — otomatik olarak çalıştırılmış sorgular değildir:

```text
site:fuarlar.tobb.org.tr/FuarTakvimi "2026" "tarım"
site:tuyap.com.tr "fuar" "gıda"
site:ito.org.tr "tedarikçi" "2026"
site:deik.org.tr "iş forumu" "Türkiye"
site:tim.org.tr "ticaret heyeti" "başvuru"
site:kommunity.com "Ankara" "etkinlik"
site:biletino.com "atölye" "İzmir"
site:kariyer.net/is-ilanlari "lojistik"
site:yenibiris.com/is-ilanlari "sağlık"
site:een.ec.europa.eu/partnering-opportunities "Türkiye"
site:kosgeb.gov.tr "başvuru" "2026"
site:tubitak.gov.tr "çağrı" "2026"
```

Yıl ve şehir parametredir; 2026 sabit kodlanmamalı. Anahtar sözcük eşleşmesi aday bulur; ilan türü, tarih ve uygunluk detay sayfasından doğrulanır. Hassas belge, açık parola veya özel sistem arama sorguları kapsamda değildir.

## 6. Tarih doğrulaması: TechAnkara örneği

Ses notundaki “Tek Ankara” ifadesi **muhtemelen TechAnkara Proje Pazarı**. Ürünün/etkinliğin varlığı doğrulandı; sesin kesin çözümü olduğu iddia edilmiyor.

- [Takvim sayfası](https://www.ankaraprojepazari.com/takvim/) 2024 tarihlerine ait. Güncel tarama tarihi, içeriğin güncel olduğu anlamına gelmiyor.
- [31 Temmuz 2026 tarihli ajans duyurusu](https://www.ankaraka.org.tr/techankara-proje-pazari-2026da-sergilenecek-projeler-aciklandi), 2026 proje başvurularının 25 Mayıs–5 Temmuz arasında alındığını ve sergilenecek projelerin seçildiğini belirtiyor. 24 Eylül 2026 itibarıyla bunu “proje başvurusu açık” şeklinde bildirmek hatalı olur.
- Ziyaretçi başvurusu, proje başvurusu ve etkinlik başlangıcı ayrı statülerdir. Güncel ziyaretçi kaydı bu çalışmada doğrulanmadı.

Bu vaka test verisine dönüştürülmeli: eski takvim yeni fırsat alarmı üretmemeli; proje başvurusu kapanmış olsa bile etkinlik kaydı ayrıca görüntülenebilmelidir.

## 7. Otomasyona geçiş kapısı

Her kaynak için sonraki araştırmacı şu alanları tamamlamalı: kanonik liste/detay URL'si, izinli erişim yöntemi, kullanım/robots kontrol tarihi, API/feed varsa resmî belgesi, kimlik doğrulama ihtiyacı, kaynak sınırları, çıkarılabilir alanlar, bilinen hata örneği ve sorumlu kişi. HTML'nin okunabilmesiyle entegrasyon tamamlanmış sayılmaz.

Önerilen ilk pilot: S01 ile çok sektörlü fuarlar; S04 ile genel etkinlikler; S11 veya S14 ile mesleki/tedarik buluşmaları; S19 veya izin sağlanırsa S17 ile işe alım. En az bir ticari teklif/ortaklık örneği de manuel doğrulanmış kayıt olarak eklenmeli. Otomatik adaptörler yalnızca erişim değerlendirmesi tamamlananlarda açılır. Günlük keşif, 6–24 saatlik kaynak kontrolü başlangıç önerisidir; sağlayıcı ve kaynak şartları belirleyicidir.

İlk envanter; bütün sektörlere aynı miktarda kaynak veya bütün illere eşit kapsama sağlamıyor. Pilot raporu sektör × il × kayıt türü tablosuyla boşlukları gösterecek; ikinci dalgada yerel oda, sektör derneği, üniversite ve organizatör kaynakları bu boşluklara göre seçilecek.
