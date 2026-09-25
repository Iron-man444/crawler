# Geniş etkinlik kapsamı

Pilot profil Türkiye genelinde tüm sektörlerin ticari ve mesleki buluşmalarını kapsar. ERP kelimesi veya doğrudan ERP entegrasyonu kanıtı aranmaz. Kaynakta belirtilen sektör ve etkinlik niteliği yeterlidir; belirli katılımcılar veya şirketlerin ERP ihtiyacı uydurulmamalıdır. MÜSİAD EXPO, mobilya, dijital baskı ve akıllı bina fuarları bu kapsama örnektir. Eğitim, sertifika, bootcamp, indirim ve salt eğlence içerikleri kapsam dışındadır.

`notify_on_reanalysis: true` pilotta açıktır. Profil değiştiğinde sonraki tarama sayfayı yeni profil ile yeniden analize kuyruğa alır. Önceden belirsiz/uygunsuz sayılan kayıt artık eşleşiyorsa bildirim üretir. Aynı profil ve URL'deki değişmeyen eşleşme tekrar gönderilmez. Farklı URL'lerdeki aynı etkinlikler henüz birleştirilmez. Ayar verilmezse eski sessiz yeniden analiz davranışı korunur.

## VPS'e uygulama

Yerel değişiklikleri GitHub'a gönderdikten sonra:

```bash
git pull --ff-only
bash scripts/vps.sh start --provider mistral --model mistral-small-2603 --sources 50
bash scripts/vps.sh status
```

Bu komut 50 kaynak pilot ayarlarını yeniden üretir; özel profil değişikliklerini eski ayar yedeğinde saklar. Mevcut günlük çağrı sınırını korur. Sınır dolmuşsa yeni analizler bütçe açılana kadar bekler. Profil değişikliği analiz önbelleğini geçersiz kılar ve yeniden API kullanımına neden olur. İlk sonuçların hemen veya 30 dakika içinde tamamlanma garantisi yoktur.

## LLM'e gönderilen sayfa boyutu

50 kaynak pilotunda HTML etiketleri ve genel menü/script gibi bölümler temizlenir; başlık, içerik metni ve varsa JSON-LD gönderilir. Siteye özel selector kullanılmaz.

- Her çağrıda en fazla 6.000 karakter kaynak metni; buna profil, talimat ve JSON şeması eklenir.
- Parçalar arasında 300 karakter örtüşme vardır. Sayfa başına en fazla 12 parça, toplam en fazla 68.700 karakter kaynak işlenebilir.
- 6.000 karakter token sayısı değildir. Türkçe metin ve JSON yoğunluğuna göre token miktarı değişir; gerçek kullanım henüz kaydedilmiyor.
- Çıktı üst sınırı 4.096 tokendır. Yoğun bir etkinlik listesinin yanıtı bu sınırda kesilebilir; eksik yanıt başarı sayılmaz.
- 68.700 karakterden uzun metin parçalara ayırma aşamasında `document_needs_review_too_long` olur; ilk 12 parça sessizce gönderilip geri kalanı atılmaz.
- `response_too_large` ayrı bir indirme sınırıdır (2 MB); LLM'in bağlam sınırı değildir.

Bu değişiklikte boyut ve günlük çağrı sınırları artırılmadı. Uzun sayfaların tamamını daha büyük tek isteğe koymak yerine genel liste/detay ayrıştırması gelecekte ayrıca geliştirilmelidir. Mevcut 60 saniyelik çağrı aralığında 12 parçalık tek bir sayfa, API yanıt süreleri ve diğer işler hariç yaklaşık 11 dakikalık bekleme gerektirir.
