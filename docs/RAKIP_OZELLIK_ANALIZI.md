# Rakip özellik analizi ve ürün kapsamına etkisi

> Kapsam güncellemesi: araştırma referans olarak korunur; aşağıdaki öncelikler güncel teslim kapsamı değildir. Sabit site + arama sorgusu, yerel/API LLM ve Python Telegram botuna aktarım [sürüm 3 görev dokümanında](TEKNIK_GOREV_DOKUMANI.md) tanımlıdır. Web ertelendi; CRM/ERP sonraki aşamadır.

Araştırma tarihi: 24 Eylül 2026. Yöntem: üreticilerin resmî ürün/dokümantasyon sayfaları. Sekiz ürün incelendi; hesap açılarak ürün testi, fiyat teklifi veya performans karşılaştırması yapılmadı. Aşağıdaki özellikler üretici beyanıdır; kullanılabilir paket, eklenti ve API şartları satın alma/entegrasyon aşamasında ayrıca doğrulanmalıdır.

## 1. Ses notundaki ürün adı

“Fenty ERP” adı doğrulanamadı. `"Fenty" "ERP"`, `"Fenty ERP" software UK` ve yakın yazımlı ERP aramaları güvenilir bir resmî ürün eşleşmesi sağlamadı. Bu, böyle bir ürünün bulunmadığını kanıtlamaz. Doğru yazım veya URL gelene kadar karşılaştırmada ayrı bir ürün gibi gösterilmemelidir.

İngiltere bağlamında Sage 200'ün UK ürün sayfası ve Workbooks CRM incelendi. Bunların ses notunda kastedilen ürün olduğu varsayılmadı.

## 2. ERP ve CRM ürünleri

| ID / ürün | Resmî kaynakta görülen özellikler | Bu projeye çıkarımımız | Paket ve sınır notu |
|---|---|---|---|
| R01 — [Odoo CRM](https://www.odoo.com/app/crm-features) | Satış süreci görünümü, teklif oluşturma, aday/fırsat takibi ve birleştirme önerileri | Kaynak kaydını doğrudan müşteri yapmak yerine inceleme ve fırsata dönüştürme adımları; tekrar birleştirme | Özellik sayfası resmî arama indeksinden incelendi; doğrudan sayfa okuma zaman aşımına uğradı. Sürüm/paket doğrulanmadı. |
| R02 — [ERPNext CRM](https://docs.frappe.io/erpnext/CRM) ve [modüller](https://frappe.io/erpnext/modules) | Lead ve Opportunity ayrımı, sorumlu, kaynak, sektör, sonraki faaliyet; satış, satın alma, stok, üretim, proje ve muhasebe modülleri | Kanıtlı kaynak kaydı → nitelendirme → görev/fırsat bağlantısı. Otomasyon çekirdeği ERP modüllerini yeniden yazmamalı | ERPNext CRM ve ayrı Frappe CRM ürününün hedef sürümdeki rolü ayrıca seçilmeli; aynı ürün varsayılmamalı. |
| R03 — [Sage 200 / UK](https://www.sage.com/en-gb/products/sage-200/) | Finans, stok, satın alma, sipariş, raporlama; API ve Microsoft entegrasyonu başlıkları; Standard/Professional ayrımı | ERP entegrasyonunda şirket/tedarikçi, teklif, görev ve harici kayıt kimliği için net sözleşme | Özellik tablosundaki her başlığın her pakette olduğu varsayılmadı. Türkiye yerelleştirmesi incelenmedi. |
| R04 — [Logo Edge T-Series](https://www.logo.com.tr/urun/logo-edge-t-series) | Finans/satış/stok/tedarik; online tedarikçi teklif toplama ve karşılaştırma; filtreleme/gruplama ve rapor panelleri | Ticari talepleri işe alım ilanından ayırmak; doğrulanmış tedarik fırsatını ERP teklif sürecine bağlamak | Eski Tiger 3 URL'si bu sayfaya yönlendi. Bazı modüller sayfada opsiyonel ücretli olarak işaretli; tümü çekirdek paket sayılmamalı. |
| R05 — [Workbooks](https://www.workbooks.com/products/) | CRM ve satış süreci, pazarlama otomasyonu, satış tahmini, sipariş işleme, proje ve müşteri hizmetleri | İlk sürümde sorumlu ve sonraki aksiyon; ileride fırsatın görüşme/teklif/sipariş sonucuna bağlanması | Tam ERP eşdeğeri olarak değerlendirilmedi. Kampanya ve operasyon yeteneklerinin paket koşulları incelenmedi. |

Bu ürünlerde web genelinde etkinlik/teklif keşfi ile Telegram bildiriminin projemizdeki akışla hazır geldiği doğrulanmış değil. Araştırma sonucu “yok” demek yerine “incelenen kaynakta doğrulanmadı” olarak kaydedilmelidir.

## 3. İzleme ve bilgi toplama ürünleri

| ID / ürün | Resmî kaynakta görülen özellikler | Bu projeye çıkarımımız | Kapsam sınırı |
|---|---|---|---|
| R06 — [Distill](https://distill.io/docs/web-monitor/what-is-distill/) ve [koşullu alarmlar](https://distill.io/docs/web-monitor/using-conditions-to-get-alert-on-important-changes/) | Yerel/bulut izleme, değişiklik geçmişi, sayfa bölümü seçimi, koşullar ve bildirim kanalları | Değişiklik tespiti ile bildirim kuralı ayrı adımlar; kaynak ve takip bazında koşullar; gürültüyü azaltma | Yerel işleyici kapalıyken tarama yapılamaz. Bizdeki kayıt sınıflandırması ayrıca geliştirilecek. |
| R07 — [Visualping](https://visualping.io/) | Değişen bölümü gösteren görüntü, AI ile değişiklik önemi, e-posta/mesaj ve entegrasyon seçenekleri | Her alarmda “ne değişti?” kanıtı; isteğe bağlı özet. Önce alan bazlı metinsel fark, görüntü sonra | Sayfa ürün tanıtımıdır; doğruluk ve plan kotaları test edilmedi. Telegram'a özgü yerleşik destek varsayılmadı. |
| R08 — [Feedly Market Intelligence](https://feedly.com/market-intelligence) | Konuya göre AI akışları, eğilim panelleri, kaynak bağlantılı özet, bülten ve entegrasyonlar | Sektör bazlı kayıtlı görünüm ve günlük özet; daha sonra kaynaklı AI özetleri | Haber/istihbarat odağı var; başvuru takvimi veya ERP iş kaydıyla aynı model değildir. |

İzleme ürünleri mevcut işleyişi anlamak için referanstır; bu çalışma bir satın alma önerisi veya bütün rakiplerin eksiksiz listesi değildir.

## 4. Özellik katmanları ve kararlar

Buradaki öncelikler bizim ürün tasarımı önerimizdir; rakiplerin yol haritası değildir. P0 ilk teslimat, P1 sonraki iyileştirme, P2 ERP sonrası genişlemedir.

| Katman | Pazar referansı | Önerilen ürün kararı | Öncelik |
|---|---|---|---|
| Kaynak ve kapsam | R06, R08 | Kaynak/domain envanteri, izin durumu, sektör/il/tür etiketleri ve son başarılı kontrol | P0 |
| İzleme | R06, R07 | Zamanlı toplama, alan bazlı değişiklik, hata durumunda eski değeri koruma | P0 |
| Bilgi kalitesi | R01, R02 | Tekilleştirme, kaynak kanıtı, belirsiz tarihleri incelemeye alma | P0 |
| Görünürlük | R03, R04, R08 | Filtrelenebilir fırsat listesi, yaklaşan tarihler, kaynak hataları | P0 |
| Bildirim | R06, R07 | Takip kuralı, yetkili Telegram hedefi, olay ve teslimat geçmişi | P0 |
| Günlük iş takibi | R02, R05 | Kaydetme, sorumlu, not ve durum; basit takip kuyruğu | P1; durum/kaydetme P0 |
| Özet ve öncelik | R07, R08 | Günlük özet, açıklanabilir önem puanı, kaynaklı AI sınıflandırması | P1 |
| CRM geçişi | R01, R02, R05 | İncelenmiş kaydı harici lead/fırsat/göreve dönüştürme | P2 |
| ERP operasyonu | R02, R03, R04 | Teklif/sipariş/tedarik kaydına bağlantı; finansal kayıt ERP'de | P2 |
| Pazarlama | R05 | Onaylanmış müşteri verileri ve iletişim tercihleriyle segment/kampanya | P2 sonrası |

## 5. İlk ürünün sınırı

İlk ürünün başarı ölçütü “çok modül” değil; kullanıcının ilgili fırsatı bulması, neden eşleştiğini görmesi, son tarihi kaçırmaması ve aynı olay için gereksiz tekrar bildirim almamasıdır.

İlk sürümde bulunması önerilenler:

1. Türkiye geneli il, sektör, kayıt türü, tarih ve anahtar sözcük filtreleri.
2. Kaynak URL'si ve gözlem tarihi görülebilen birleşik liste.
3. Yeni kayıt, tarih değişikliği, iptal/kapanış ve yaklaşan son tarih olayları.
4. Kaydetme, ilgisiz işaretleme ve açıklanabilir tekrar gruplama.
5. Telegram hedefi ve abonelik kuralı; deneme mesajı ve teslimat hatası görünürlüğü.
6. İzin, son kontrol, hata ve duraklatma bilgisiyle kaynak yönetimi.
7. Yeniden başlatmaya dayanıklı işler, tekilleştirme ve bildirim kuyruğu.

İlk sürüme alınmayan rakip katmanları: muhasebe, bordro, stok hareketi, üretim planlama, otomatik müşteriyle iletişim, AI satış tahmini ve çok kuruluşlu pazarlama. Bunlar mevcut ERP'nin sorumluluğu veya sonraki ürün kararıdır.

## 6. Rakip demosunda sorulacak somut sorular

- Kaynak kaydının ilk geldiği URL ve bütün güncellemeleri korunuyor mu?
- Aynı şirket/fırsat iki kaynaktan geldiğinde birleştirme geri alınabiliyor mu?
- Son tarih değişince eski hatırlatma iptal oluyor mu?
- API aynı isteği iki kez aldığında tek kayıt mı üretiyor; harici kimlikle sorgu var mı?
- Rol, kullanıcı ve şirket kapsamı API tarafında uygulanıyor mu?
- Özellik çekirdek pakette mi, ücretli ek modül mü; dışa aktarma ve API kotaları ne?

Bu soruların yanıtları mevcut ERP backend'i geldiğinde `var / kısmi / yok / doğrulanmadı` olarak doldurulacak. Henüz görmediğimiz backend için eksik özellik tespiti yapılmış sayılmamalıdır.
