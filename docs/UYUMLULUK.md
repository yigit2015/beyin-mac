# Kasa uyumluluğu

Beyin kasayı yalnız okur. Bu sayfa neyi nasıl okuduğunu ve neyi atladığını anlatır.

## Esas alınan sözleşme

avenoxbeyin kasaları için esas, avenoxbeyin'in
[docs/v3/MARKDOWN.md](https://github.com/avenoxai/avenoxbeyin/blob/main/docs/v3/MARKDOWN.md) belgesidir. Beyin onun
kodunu çalıştırmaz ve sözleşmeyi birebir uygulamaz; onunla uyumlu okumaya çalışır. Bir notun Beyin'de avenoxbeyin'den
farklı göründüğünü fark edersen lütfen bir [issue](https://github.com/yigit2015/beyin-mac/issues) aç.

Bu uyumluluk, avenoxbeyin'in klasör sözleşmesi kesinleşmeden yapıldı
([avenoxbeyin #478](https://github.com/avenoxai/avenoxbeyin/issues/478)). Sözleşme değişirse Beyin de güncellenir.

## Hiçbir klasör varsayılmaz

Temiz bir avenoxbeyin V3 kurulumu eski şablon ağacını (`🏰 300-Projects`, `📋 Templates`…) kopyalamaz
(`scripts/install_v3.py`). Beyin bu yüzden hiçbir klasörün var olduğunu varsaymaz; varsa kullanır, yoksa aramaz.

## Atlananlar

avenoxbeyin'in tarayıcısıyla aynı:

- Gizli dosya ve klasörler (`.obsidian`, `.claude`…), `node_modules`, `receipts`, `__pycache__` ve sembolik bağlar.
- Talimat ve ayar dosyaları: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `SKILL.md`, `HOOKS.md`, `CONFIG.md`,
  `SETTINGS.md`, `INSTRUCTIONS.md`, `CODEX.md`, `SETUP.md`, `INSTALL.md` ve `setup-*.md`. Büyük/küçük harf
  duyarsız, her derinlikte.
- `kind: receipt` ya da `generated: true` olan notlar.
- Adında kasa, şifre, parola, kimlik, finans, müşteri, vergi, fatura, maaş, özel, gizli, private, secret, password
  ya da credential kelimesi geçen klasörler (avenoxbeyin'in hassas klasör kuralı; Türkçe harfler sadeleştirilerek
  kelime kelime karşılaştırılır).
- Kullanıcının avenoxbeyin'de `beyin.py preferences --index-exclude-dir AD` ile dışladığı klasörler. Liste, kasadaki
  `.beyin-runtime.json`'ın gösterdiği state klasöründeki `index.json`'dan okunur.

Beyin'in ek önlemleri (avenoxbeyin bunları indeksler, Beyin not olarak göstermez):

- Şablon klasörü. Sabit bir adla değil, Obsidian'ın Şablonlar ve Templater ayarlarından (`.obsidian/templates.json`,
  Templater'ın `data.json`'ı) bulunur.
- Frontmatter değerlerinden biri tam olarak yer tutucu olan notlar (`created: {{TODAY}}`, Templater `<% … %>`).
  Gerçek bir notta bu değer kalmaz; avenoxbeyin'in tohumladığı `📋 Templates/Kisi.md` de böyle anlaşılır.

## Çekirdek (companion) klasörü

Keşifle bulunur: kökte adı `companion` ya da `echo` ile biten klasör; yoksa içinde `Core.md` ya da `Soul.md` olan
klasör. Adı arşiv olduğunu gösteren klasörler sayılmaz. Birden fazla aday varsa çekirdek seçilmez.

## Kategoriler

Sıra şöyledir; ilk tutan kazanır:

1. Çekirdek klasöründeki notlar çekirdektir.
2. Frontmatter `kind`: `fact`, `person`, `task`, `daily`.
3. Proje klasörü: `projects/<proje>/<alt>/` ya da resmi şablondaki `🏰 300-Projects/<proje>/<alt>/`
   (`projects/sohbet-arsivi/` sohbet sayılır).
4. Frontmatter `project`.
5. Klasör adları: `daily/`, `tasks/`, `notes/kisiler/`.

avenoxbeyin kasası olmayan bir kasada (çekirdek klasörü ve `.beyin-runtime.json` yok) her üst klasör bir küme olur.

## Frontmatter

- JSON ya da MARKDOWN.md'deki düz YAML alt kümesi: düz skaler, tek satır liste (`[a, "b c"]`), girintili liste,
  satır sonunda `# yorum`, `# kind: x` gibi yorum satırları. Desteklenmeyen yapılarda (çok satırlı değer, iç içe
  liste…) avenoxbeyin dosyayı uyarıyla dışarıda bırakır; Beyin notu gösterir ve okuyabildiği alanları kullanır.
- Tarih: `tarih`, `date`, `created` ya da `created_at`; güncelleme için `updated_at`, `updated`, `modified`,
  `last_modified`, `date_modified`. Yoksa dosyanın kendi tarihleri.
- `visibility`: `public`, `internal` ya da `private`. Private notun içeriği gösterilmez ve aramaya girmez.
  Tanınmayan bir değer güvenli tarafta kalınarak private sayılır.

## Bağlantılar

`[[wikilink]]`'ler ada göre, büyük/küçük harf duyarsız ve Unicode NFC karşılaştırmasıyla çözülür; macOS'un ayrışık
yazdığı dosya adları da eşleşir.
