#!/usr/bin/env python3
"""Uydurma bir örnek kasa üretir: Ornek-Kasa/ (avenoxbeyin düzeninde, gerçek bir kişiye ait değil).

Ekran görüntüleri ve uygulamayı kendi notlarını açmadan denemek için. Çalıştırma: python3 Scripts/ornek_kasa.py
"""
import json
import os
import random
import shutil
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "Ornek-Kasa"
TODAY = datetime(2026, 10, 27, 10, 0)
rng = random.Random(7)


def write(path, title, body, kind=None, days_ago=0, links=(), visibility=None, project=None):
    date = TODAY - timedelta(days=days_ago, hours=rng.randint(0, 9))
    meta = {"title": title, "date": date.strftime("%Y-%m-%dT%H:%M:%S")}
    if kind:
        meta["kind"] = kind
    if project:
        meta["project"] = project
    if visibility:
        meta["visibility"] = visibility
    text = "---\n" + json.dumps(meta, ensure_ascii=False) + "\n---\n# " + title + "\n\n" + body.strip() + "\n"
    if links:
        text += "\n## Bağlantılar\n\n" + "\n".join("- [[" + link + "]]" for link in links) + "\n"
    file = ROOT / path
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text, encoding="utf-8")
    stamp = date.timestamp()
    os.utime(file, (stamp, stamp))


def pick(pool, k):
    return rng.sample(pool, min(k, len(pool)))


if ROOT.exists():
    shutil.rmtree(ROOT)

# Çekirdek: Claude'un her oturumda okuduğu hafıza dosyaları.
companion = "🔮 850-Companion/"
write(companion + "Core.md", "Core", "Deniz'in düşünme ortağı ve ikinci beyniyim. Kısa ve net cevaplar sever, "
      "öğrenirken örnekle ilerler.", links=["Kurallar", "Swift öğrenme yolu", "Mobil uygulama fikri"])
write(companion + "Kurallar.md", "Kurallar", "1. Önce özet, sonra ayrıntı.\n2. Kaynağı belirsiz bilgiyi işaretle.\n"
      "3. Haftalık planı pazartesi güncelle.", days_ago=2, links=["Haftalık rutin"])
write(companion + "Last-Session.md", "Last-Session", "Son oturumda mutfak tadilatı bütçesi çıkarıldı, kitap kulübü "
      "için kasım kitabı seçildi.", links=["Mutfak bütçesi", "Kasım kitabı"])
write(companion + "Threads.md", "Threads", "Açık konular: uygulamanın onboarding akışı, banyo fayans kararı, "
      "koşu programının 3. haftası.", days_ago=1, links=["Onboarding akışı", "Fayans seçimi", "Koşu programı"])
write(companion + "Journal.md", "Journal", "Bu hafta odak: düzenli uyku ve uygulama prototipi.", days_ago=1)

knowledge = {
    "Swift öğrenme yolu": "Önce Swift temelleri, sonra SwiftUI ile küçük ekranlar, en son veri katmanı.",
    "SwiftUI düzen ipuçları": "VStack ve HStack ile başla, Grid'i tablo benzeri yerlerde kullan.",
    "Pomodoro tekniği": "25 dakika odak, 5 dakika mola; dört turdan sonra uzun mola.",
    "Derin çalışma": "Bildirimleri kapat, tek işe 90 dakika ayır.",
    "Kahve demleme oranları": "Filtre kahvede 1:16 oranı, 94 °C su.",
    "50-30-20 bütçe kuralı": "Gelirin yarısı ihtiyaç, %30 istek, %20 birikim.",
    "Bütçe takibi": "Aylık giderleri kategoriye göre topla, sabit giderleri ayrı izle.",
    "Koşu programı": "Haftada üç gün; yürüyüş ve koşu aralıklarını her hafta uzat.",
    "Uyku düzeni": "Her gün aynı saatte kalk, yatmadan bir saat önce ekranı bırak.",
    "Haftalık rutin": "Pazartesi planlama, cuma kısa değerlendirme.",
    "Okuma listesi": "Bu yıl için 12 kitap; ayda bir kitap kulübü kitabı.",
    "Not alma yöntemi": "Her not tek fikir; bağlantılarla büyüyen bir ağ.",
    "Obsidian düzeni": "Klasör az, bağlantı çok. Günlük notlar daily/ altında.",
    "Git temelleri": "Küçük commit, anlamlı mesaj, her özellik ayrı dal.",
    "Fotoğraf saklama": "Telefon yedekleri ayda bir harici diske.",
    "Tarif defteri": "Denenmiş tarifler ve porsiyon notları.",
    "Ekmek mayası": "Ekşi maya her gün beslenmeli; buzdolabında haftada bir.",
    "Bahçe sulama": "Sabah erken sula; damla sulama su tasarrufu sağlar.",
    "Sunum hazırlama": "Tek slayt tek fikir; sayılar büyük, yazı az.",
    "Yapay zekâ ile çalışma": "Bağlamı net ver, çıktıyı her zaman doğrula.",
    "Klavye kısayolları": "⌘K arama, ⌘⇧P komut paleti, ⌥⌘ pencere düzeni.",
    "Seyahat çantası listesi": "Şarj aleti, adaptör, ilaç, kimlik.",
}
titles = list(knowledge)
for i, (title, body) in enumerate(knowledge.items()):
    write("knowledge/" + title + ".md", title, body, kind="fact", days_ago=3 + i * 2,
          links=pick([t for t in titles if t != title], rng.choice([0, 1, 2, 2, 3])))

people = {
    "Ece": ("Kitap kulübünü düzenliyor, bilim kurgu sever.", None),
    "Mert": ("Koşu arkadaşı; pazar sabahları sahilde.", None),
    "Selin": ("Uygulama fikri için tasarım desteği veriyor.", None),
    "Usta Hasan": ("Mutfak tadilatı ustası. Telefon ve fiyat bilgisi özel.", "private"),
    "Bora": ("Git ve Swift sorularında yardımcı.", None),
}
for i, (name, (body, visibility)) in enumerate(people.items()):
    write("notes/kisiler/" + name + ".md", name, body, kind="person", days_ago=5 + i * 4, visibility=visibility,
          links=pick(["Kitap kulübü", "Koşu programı", "Mobil uygulama fikri", "Mutfak bütçesi", "Git temelleri"], 1))

tasks = ["Onboarding akışı", "Fayans seçimi", "Kasım kitabı", "Mutfak bütçesi", "Vergi belgelerini topla",
         "Yedekleri kontrol et", "Koşu ayakkabısı al", "Sunum provası"]
for i, title in enumerate(tasks):
    write("tasks/" + title + ".md", title, "- [ ] İlk adım\n- [ ] Son kontrol", kind="task", days_ago=1 + i * 3,
          links=pick(titles + ["Mobil uygulama fikri", "Kitap kulübü"], rng.choice([1, 2])))

for d in range(0, 28, 2):
    date = (TODAY - timedelta(days=d)).strftime("%Y-%m-%d")
    write("daily/" + date + ".md", date, "Günün notu: " + rng.choice(
        ["odaklı bir gün", "toplantı yoğun", "koşu + okuma", "tadilat görüşmesi", "prototip üzerinde çalıştım"]) + ".",
        kind="daily", days_ago=d, links=pick(tasks + titles, rng.choice([1, 2, 3])))

projects = {
    "mobil-uygulama": {
        "tasarim": ["Mobil uygulama fikri", "Renk paleti", "Ekran akışı", "İkon taslakları", "Kullanıcı görüşmeleri"],
        "kod": ["Veri modeli", "Senkronizasyon", "Bildirimler", "Test planı", "Hata listesi"],
        "pazarlama": ["Uygulama adı", "Mağaza açıklaması", "Lansman planı"],
    },
    "ev-tadilati": {
        "mutfak": ["Mutfak planı", "Dolap ölçüleri", "Tezgâh seçenekleri", "Usta teklifleri"],
        "banyo": ["Banyo planı", "Duş seçenekleri", "Havalandırma"],
    },
    "kitap-kulubu": {
        None: ["Kitap kulübü", "Ekim kitabı: Sapiens", "Eylül kitabı: Dune", "Tartışma soruları", "Kulüp kuralları",
               "Okunacaklar havuzu"],
    },
}
for project, groups in projects.items():
    names = [n for group in groups.values() for n in group]
    for sub, notes in groups.items():
        for i, title in enumerate(notes):
            folder = "projects/" + project + "/" + (sub + "/" if sub else "")
            hub = notes[0]
            links = [] if i == len(notes) - 1 and sub == "pazarlama" else [hub] if title != hub else []
            links += pick([n for n in names if n != title], rng.choice([0, 1, 2]))
            if rng.random() < 0.3:
                links += pick(titles, 1)
            write(folder + title + ".md", title, "Proje notu: " + title.lower() + ".", project=project,
                  days_ago=rng.randint(0, 50), links=list(dict.fromkeys(links)))

chats = ["Haftalık plan", "Swift hata ayıklama", "Tadilat bütçesi hesabı", "Kitap önerileri", "Uygulama adı fikirleri",
         "Koşu programı ayarı", "Sunum taslağı", "Ekmek tarifi sorusu"]
for i, title in enumerate(chats):
    date = TODAY - timedelta(days=i * 3)
    write("projects/sohbet-arsivi/" + date.strftime("%Y-%m") + "/" + date.strftime("%Y-%m-%d %H%M ") + title + ".md",
          title, "## Sen\n\n" + title + " hakkında konuşalım.\n\n## Claude\n\nTabii, önce hedefi netleştirelim.",
          kind="note", project="sohbet-arsivi", days_ago=i * 3,
          links=pick(titles + tasks, rng.choice([0, 1, 2])))

# Bağlantısız ve henüz yazılmamış notlar: gerçek bir kasadaki gibi.
for i, title in enumerate(["Rastgele fikir", "Film listesi", "Hediye fikirleri", "Kelime defteri", "Podcast notları"]):
    write("knowledge/" + title + ".md", title, "Kısa bir not.", kind="fact", days_ago=10 + i * 7)
write("knowledge/Gelecek planları.md", "Gelecek planları", "Henüz taslak.", kind="fact", days_ago=4,
      links=["Henüz yazılmadı", "Yurt dışı yüksek lisans"])

print(sum(1 for _ in ROOT.rglob("*.md")), "not yazıldı:", ROOT)
