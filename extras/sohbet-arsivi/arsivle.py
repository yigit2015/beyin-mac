#!/usr/bin/env python3
"""Claude Code Stop hook: konuşmayı okunabilir Markdown olarak <kasa>/projects/sohbet-arsivi/ altına yazar.

Yalnız kullanıcı ve asistan metni yazılır; araç çıktıları atılır. API anahtarı, token, kart ve IBAN
gibi kalıplar maskelenir; dosyalar yalnız sahibinin okuyabileceği izinle (600) yazılır.

Ayarlar (ortam değişkeni):
  BEYIN_VAULT  kasa klasörü (varsayılan ~/Beyin)
  BEYIN_AD     sohbetteki adın (varsayılan "Sen")
Kapatmak için kasada .arsiv-kapali dosyası oluştur. Hata olursa sessizce çıkar, Claude'u durdurmaz.
"""
import json, os, re, sys, tempfile
from datetime import datetime
from pathlib import Path

VAULT = Path(os.environ.get("BEYIN_VAULT") or Path.home() / "Beyin").expanduser()
OUT = VAULT / "projects" / "sohbet-arsivi"
LOG = Path.home() / ".config" / "beyin" / "arsivle.log"
MAX_MSG = 8000
USER_NAME = os.environ.get("BEYIN_AD") or "Sen"

SECRETS = [
    r"apikey_[A-Za-z0-9_]{10,}", r"sk-[A-Za-z0-9_-]{20,}", r"gh[pousr]_[A-Za-z0-9]{20,}",
    r"AKIA[0-9A-Z]{16}", r"xox[bap]-[A-Za-z0-9-]{10,}", r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_.-]+",
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----",
    r"\b(?:\d[ -]?){15}\d\b", r"\bTR\d{2}(?:[ ]?\d{4}){5}[ ]?\d{2}\b",
    r"(?i)\b(password|parola|şifre|sifre|token|secret|api[_-]?key)\b(\s*[:=]\s*)\S{6,}",
]
SECRET_RE = [re.compile(p) for p in SECRETS]
REMINDER = re.compile(r"<system-reminder>[\s\S]*?</system-reminder>")
TAGS = re.compile(r"<(command-name|command-message|command-args|local-command-stdout)>[\s\S]*?</\1>")


def mask(text):
    for rx in SECRET_RE:
        if rx.groups >= 2:
            text = rx.sub(lambda m: m.group(1) + m.group(2) + "[GİZLİ]", text)
        else:
            text = rx.sub("[GİZLİ]", text)
    return text


def clean(text):
    text = REMINDER.sub("", text)
    text = TAGS.sub("", text)
    return text.strip()


def texts(message):
    content = message.get("content")
    if isinstance(content, str):
        return [content]
    out = []
    for block in content or []:
        if isinstance(block, dict) and block.get("type") == "text":
            out.append(block.get("text", ""))
    return out


def main():
    if (VAULT / ".arsiv-kapali").exists() or not VAULT.is_dir():
        return
    event = json.load(sys.stdin)
    transcript = Path(event.get("transcript_path", ""))
    if not transcript.is_file():
        return
    session = str(event.get("session_id", ""))[:8] or "oturum"
    turns, first_ts = [], None
    with transcript.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if entry.get("isSidechain") or entry.get("type") not in ("user", "assistant"):
                continue
            role = USER_NAME if entry["type"] == "user" else "Claude"
            body = clean("\n\n".join(texts(entry.get("message", {}))))
            if not body:
                continue
            first_ts = first_ts or entry.get("timestamp")
            if len(body) > MAX_MSG:
                body = body[:MAX_MSG] + "\n\n[… kısaltıldı]"
            turns.append((role, mask(body)))
    if not turns:
        return
    try:
        start = datetime.fromisoformat(first_ts.replace("Z", "+00:00")).astimezone()
    except Exception:
        start = datetime.now()
    first = turns[0][1].splitlines()[0]
    # "/Users/ad/Downloads/plan.md bunu oku" → "plan.md bunu oku": mutlak yolları dosya adına indir.
    first = re.sub(r"(?:~|/Users/[^/\s]+)(?:/[^/\s]+)*/([^/\s]+)", r"\1", first)
    title = re.sub(r"\s+", " ", first).strip()[:60]
    slug = re.sub(r"[^\w\- ]", "", title, flags=re.UNICODE).strip() or "sohbet"
    folder = OUT / start.strftime("%Y-%m")
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "{} {} ({}).md".format(start.strftime("%Y-%m-%d %H%M"), slug, session)
    meta = {"kind": "note", "project": "sohbet-arsivi", "visibility": "internal",
            "remote_allowed": False, "title": title, "session": session,
            "cwd": event.get("cwd", "")}
    parts = ["---", json.dumps(meta, ensure_ascii=False, indent=2), "---", "# " + title, ""]
    for role, body in turns:
        parts += ["## " + role, "", body, ""]
    data = "\n".join(parts)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=folder, delete=False, suffix=".tmp") as tmp:
        os.chmod(tmp.name, 0o600)
        tmp.write(data)
    os.replace(tmp.name, path)
    # Başlık değiştiyse aynı oturumun eski adlı kopyasını kaldır (tek oturum = tek dosya).
    for old in OUT.glob("*/*({}).md".format(session)):
        if old != path:
            old.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        try:
            LOG.parent.mkdir(parents=True, exist_ok=True)
            with LOG.open("a") as log:
                log.write("{} {}: {}\n".format(datetime.now().isoformat(timespec="seconds"), type(exc).__name__, exc))
        except Exception:
            pass
    sys.exit(0)
