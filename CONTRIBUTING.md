# Katkı

Hata bildirimi, öneri ve PR'lar memnuniyetle karşılanır.

- **Önce issue:** Büyük bir değişiklik düşünüyorsan önce bir [issue](https://github.com/yigit2015/beyin-mac/issues) aç,
  birlikte konuşalım. Küçük düzeltmeler için doğrudan PR açabilirsin.
- **Salt okunur kalır:** Beyin kasaya asla yazmaz ve ağ isteği yapmaz. Bu iki kuralı bozan değişiklik kabul edilmez.
- **Gerçek not yok:** Test, ekran görüntüsü ve örneklerde yalnız uydurma veri kullan (`Ornek-Kasa/`,
  `Tests/BeyinCoreTests/Fixtures/`). Kendi kasandan hiçbir şey ekleme.
- **Test:** `swift test` geçmeli. Kasa okuma, wikilink ya da kategori mantığını değiştiriyorsan bir test ekle.

## Yapı

| Klasör | İçerik |
|---|---|
| `Sources/BeyinCore` | Kasa okuma, frontmatter, wikilink çözümü, grafik, yerleşim, arama, klasör izleme |
| `Sources/Beyin` | SwiftUI arayüzü: görünümler, paneller, tasarım sistemi |
| `Tests/BeyinCoreTests` | Çekirdek testleri ve küçük bir sahte kasa |
| `Scripts` | Paketleme (`package_app.sh`) ve örnek kasa üretici |
| `docs` | Kurulum sayfası (GitHub Pages) |
| `extras` | İsteğe bağlı araçlar (sohbet arşivi kancası) |
