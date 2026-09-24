# ERP backend sahibine iletilecek entegrasyon ve özellik talebi

> Ertelenmiş aşama: bu belge ilerideki ERP ihtiyacı için referanstır. Mevcut ilk teslimat sabit site/Google sorgusu → yerel veya API LLM → Telegram akışıdır; web ve ERP ilk sürümde yoktur. [Güncel görev dokümanı](TEKNIK_GOREV_DOKUMANI.md) esas alınır.

24 Eylül 2026 — önerilen sözleşme. Mevcut ERP backend'i incelenmedi; aşağıdakiler var olduğu iddia edilen endpoint veya tespit edilmiş eksik değildir. Bu metin paylaşılmaya hazır taslaktır; bu çalışma sırasında kimseye gönderilmedi.

## 1. İletilecek kısa açıklama

AI/yazılım/siber güvenlik ve iş ortaklığı etkinliklerini; ardından eğitim, bootcamp ve sertifika fırsatlarını takip eden TUI + web radarı planlıyoruz. Telegram gönderimini kullanıcının Python botu üstlenecek. Önce radar, sonra katılım/görüşme notları ve kontrollü blog yayını tamamlanacak. CRM/ERP aşamasında incelenmiş etkinlik ve görüşmeler görev/fırsat kayıtlarına bağlanacak. Kaynak ve değişiklik geçmişi korunmalı; yeniden deneme ikinci ERP kaydı açmamalı. Aşağıdaki özelliklerin backend'de hangilerinin hazır, kısmi veya planlı olduğu değerlendirilmelidir. Güncel ürün kapsamı [sürüm 2 görev dokümanındadır](TEKNIK_GOREV_DOKUMANI.md).

## 2. Backend özellik değerlendirme tablosu

Durum sütunu ERP sahibi tarafından `var / kısmi / yok / planlı` olarak doldurulacak. Şimdilik tümü bilinmiyor.

| ID | İhtiyaç | Neden gerekli? | Öncelik | Mevcut durum |
|---|---|---|---|---|
| E01 | API sözleşmesi, test ortamı ve örnek yanıtlar | Frontend ve adaptör bağımsız geliştirilsin | Entegrasyon öncesi | Bilinmiyor |
| E02 | Servis kimliği, rol ve kuruluş kapsamı | Doğru şirketin kayıtlarına sınırlı erişim | Entegrasyon öncesi | Bilinmiyor |
| E03 | Harici sistem + harici kayıt kimliği | Aynı fırsatı yeniden aktarırken bulabilmek | Entegrasyon öncesi | Bilinmiyor |
| E04 | İdempotent oluşturma/güncelleme | Timeout sonrası çift kayıt açılmaması | Entegrasyon öncesi | Bilinmiyor |
| E05 | Görev veya genel iş kaydı | Etkinlik ve destek çağrısına takip aksiyonu atamak | İlk entegrasyon | Bilinmiyor |
| E06 | Lead/fırsat/şirket modeli ve ilişki kurma | Nitelendirilmiş ticari kaydı CRM'e bağlamak | İlk entegrasyon | Bilinmiyor |
| E07 | Kaynak URL, not, etiket ve tarih alanları | Kararın dayandığı kanıt korunmalı | İlk entegrasyon | Bilinmiyor |
| E08 | Sorumlu kullanıcı, durum ve son tarih | Kaydı yapılacak işe dönüştürmek | İlk entegrasyon | Bilinmiyor |
| E09 | Kaydı kim/ne zaman değiştirdi bilgisi | Denetim ve güncelleme çatışmaları | İlk entegrasyon | Bilinmiyor |
| E10 | Değişiklik sorgusu veya imzalı webhook | ERP sonucunu dashboard'a geri yansıtmak | Sonraki adım | Bilinmiyor |
| E11 | Teklif/tedarik talebi/sipariş bağlantısı | Ticari fırsatı operasyonla ilişkilendirmek | Sonraki adım | Bilinmiyor |
| E12 | İletişim tercihleri ve izin kayıtları | İleride pazarlama iş akışını sınırlandırmak | Pazarlama öncesi | Bilinmiyor |

Rakip dayanakları ve neden bu katmanların seçildiği [özellik analizinde](RAKIP_OZELLIK_ANALIZI.md) yer alır. Bu liste mevcut ERP'nin bütün muhasebe/üretim modüllerini değerlendirmek için yeterli değildir; yalnızca bu aracın entegrasyon yüzeyidir.

## 3. Kayıt türü → ERP hedefi

| Kaynak kaydı | Önerilen ERP karşılığı | Koşul |
|---|---|---|
| Etkinlik | Katılım/araştırma görevi veya takvim kaydı | Kullanıcı seçimi; organizatör otomatik müşteri olmaz |
| Eğitim / bootcamp | Katılım veya başvuru görevi | Tarih, katılım uygunluğu ve kullanıcının seçimi doğrulanmalı |
| Sertifika / eğitim teklifi | Değerlendirme görevi; sonra gerekirse satın alma talebi | Fiyat ve paket/kupon şartı doğrulanmalı; otomatik satın alma yok |
| İş ortaklığı görüşmesi | Şirket ilişkisi, takip görevi ve nitelendirilmiş fırsat | Görüşme gerçekleşmesi ile ortaklık anlaşması ayrı durumlar |
| Katılım / blog kaydı | İlgili etkinliğe bağlı faaliyet ve içerik referansı | Özel görüşme notları otomatik kamuya açılmaz |

İlk entegrasyon tek yönlü ve kullanıcı tetiklemeli olsun: “ERP'de görev oluştur”. Bu akış doğrulandıktan sonra fırsat/tedarik eşlemeleri ve durum geri bildirimi eklenir. Genel web kaydı otomatik iletişim izni veya müşteri ilişkisi anlamına gelmez.

## 4. Asgari API sözleşmesi önerisi

Endpoint adları mevcut ERP standardına göre uyarlanabilir. Gerekli davranışlar:

- `POST /api/integrations/opportunities`: harici kaydı kabul et; `Idempotency-Key` ve servis kimliği zorunlu.
- `GET /api/integrations/opportunities/by-external-ref?...`: yanıt kaybolduğunda dış kimlikle sonucu bul.
- `GET /api/reference-data`: yetkili kullanıcının şirket, kullanıcı, durum ve kategori kimliklerini döndür; gerekiyorsa ayrı uçlara böl.
- Kayıt güncellemesi için sürüm kontrollü `PATCH` veya sürümlü içe aktarım. Kayıt ERP'de elle değiştirilmişse sessizce ezme.

İlk PoC için eşzamanlı yanıt tercih edilir: yeni kayıt 201, aynı yükün tekrarında aynı ERP kimliğiyle 200, alan hatasında 422, yetki hatasında 401/403. Aynı idempotency anahtarı farklı yükle gelirse 409. ERP asenkron çalışıyorsa ayrıca iş kimliği ve sonuç sorgusu gerekir; 202 yanıtı “ERP kaydı oluşturuldu” olarak gösterilmez.

Kuruluş + dış sistem + dış kayıt kimliği üzerinde kalıcı benzersizlik bulunmalı. İşlem anahtarı aynı aktarım sürümünün tekrarlarında korunmalı; idempotency anahtarı süresi dolsa bile dış kimlik çift kaydı önlemeli.

Aşağıdaki veri tamamen sözleşme örneğidir; gerçek fırsat veya gerçek müşteri değildir:

```json
{
  "schema_version": "1.0",
  "external_system": "opportunity-monitor",
  "external_record_id": "demo-record-001",
  "external_record_version": 3,
  "organization_scope_id": "demo-company",
  "requested_entity_type": "task",
  "title": "Örnek sektörel etkinliği değerlendir",
  "kind": "event",
  "source_url": "https://example.com/events/demo",
  "observed_at": "2026-09-24T09:00:00Z",
  "starts_on": "2026-10-15",
  "application_deadline": null,
  "timezone": "Europe/Istanbul",
  "date_precision": "date",
  "sectors": ["manufacturing"],
  "city": "Ankara",
  "assignee_id": null,
  "notes": "Demo kayıt; gerçek bir başvuru veya iletişim talebi değildir."
}
```

Başarılı yanıtta asgari alanlar: `erp_entity_type`, `erp_entity_id`, `external_record_id`, `external_record_version`, `created_or_updated`, `erp_updated_at`. Gerekirse yetkilendirilmiş `erp_record_url`. Gönderilen kuruluş kapsamı servis hesabının yetkisiyle sunucuda doğrulanır; istemcinin beyanına güvenilmez.

## 5. Alan sahipliği ve hatalar

Kaynak URL'si, kaynakta görülen tarihler ve dış kayıt sürümü takip sistemine aittir. ERP'deki ticari aşama, sorumlu, teklif tutarı ve satış sonucu ERP'ye aittir. Kaynak tarihinin değişmesi ERP'de elle konulan görev son tarihini otomatik ezmez; değişiklik önerisi veya ayrı kaynak tarihi alanı güncellenir.

Aktarım durumları: hazırlanıyor → bekliyor → başarılı / tekrar denenecek / hata / çatışma. Son deneme, hata nedeni ve ERP kimliği dashboard'da görünür. 429/5xx için sınırlı retry; 4xx doğrulama ve yetki hataları incelemeye gider. Kimlik bilgileri ve tam müşteri yükü hata loglarına yazılmaz.

ERP veritabanına doğrudan yazılmamalı. Kaynak kaydı silinmesi veya yayından kalkması ERP görevini/müşterisini kendiliğinden silmez. Silme ve bağlantıyı kaldırma ayrı işlemlerdir. İleride webhook kullanılacaksa imza, zaman damgası ve tekrar saldırısı kontrolü yapılır.

## 6. İlk demo kabul senaryosu

1. Kullanıcı doğrulanmış bir kaydı açar ve ERP'de görev oluşturmayı seçer.
2. Yetkili şirket ve varsa sorumlu seçilir; gönderilecek alanlar görünür.
3. ERP aynı dış kimlikle tek görev oluşturur ve kimliğini döndürür.
4. Aynı işlem tekrarlandığında ikinci görev oluşmaz.
5. Yanıt kaybı simüle edilir; dış kimlikle sorgulama mevcut görevi bulur.
6. Yetkisiz şirkete aktarım reddedilir; veri diğer şirkete sızmaz.
7. ERP kapalıyken işlem kuyrukta kalır; tekrar deneme sonrası sonuç kayda bağlanır.
8. Kaynak tarihi değişince ERP'deki elle atanmış görev tarihi sessizce değiştirilmez.

Backend sahibinden ilk istenecekler: doğru ürün/repo sürümü, OpenAPI veya örnek API, test URL'si, güvenli kanaldan test kimliği, şirket/rol modeli, görev/fırsat örnek JSON'u, hata formatı, limitler ve harici kimlik desteği. “Fenty ERP”nin doğru adı/URL'si gelirse rakip analizi ayrıca tamamlanır.
