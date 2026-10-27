# Sohbet arşivi (Claude Code)

`arsivle.py`, Claude Code'un **Stop** kancasıdır: her yanıttan sonra o konuşmayı kasandaki
`projects/sohbet-arsivi/YYYY-AA/` klasörüne tek bir Markdown dosyası olarak yazar (aynı oturum = aynı dosya).

- Yalnız senin ve Claude'un metni yazılır; araç çıktıları atılır.
- API anahtarı, token, kart numarası, IBAN gibi kalıplar `[GİZLİ]` ile maskelenir. Bu bir güvenlik ağıdır,
  garanti değildir: sohbete gizli bilgi yapıştırma.
- Dosyalar `600` izinle (yalnız sen) yazılır, frontmatter'da `"remote_allowed": false` bulunur.
- Python 3.9+ standart kütüphanesi yeterli, ek paket yok.

## Kurulum

```bash
mkdir -p ~/.config/beyin
curl -fsSL https://raw.githubusercontent.com/yigit2015/beyin-mac/main/extras/sohbet-arsivi/arsivle.py \
  -o ~/.config/beyin/arsivle.py
```

İndirdiğin dosyayı açıp oku; sonra `~/.claude/settings.json` içine ekle (dosyada `hooks` varsa `Stop` dizisine ekle):

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "python3 ~/.config/beyin/arsivle.py" } ] }
    ]
  }
}
```

Kasan `~/Beyin` değilse veya sohbetlerde başka bir ad görmek istiyorsan komutu şöyle yaz:

```
BEYIN_VAULT=~/Belgeler/Kasam BEYIN_AD=Deniz python3 ~/.config/beyin/arsivle.py
```

## Kapatma

- Geçici: kasanın kökünde `.arsiv-kapali` adlı boş bir dosya oluştur.
- Kalıcı: `settings.json`'daki satırı sil.

Hatalar Claude'u durdurmaz; `~/.config/beyin/arsivle.log` dosyasına yazılır.
