#!/usr/bin/env bash
# Beyin'in "ağa çıkmaz, kasaya yazmaz" iddiasını kendin kontrol etmen için.
#
#   Scripts/verify_offline.sh                 # release derler, ikiliyi ve kaynağı denetler
#   Scripts/verify_offline.sh Beyin.app       # paketlenmiş uygulamayı (ve kaynağı) denetler
#   Scripts/verify_offline.sh yol/Beyin       # verilen ikiliyi (ve kaynağı) denetler
#
# Yalnız macOS'un ve Xcode komut satırı araçlarının yerleşik araçlarını kullanır (grep, otool, nm, strings,
# codesign, plutil). Şüpheli bir şey bulursa ne bulduğunu yazar ve 1 ile çıkar; her şey temizse 0.
#
# Sınırları: Bu bir güvenlik denetimi değildir. Uygulamanın kendi kodunun ağ ve yazma API'lerini çağırmadığını
# gösterir; Apple'ın sistem çerçevelerinin (Foundation, AppKit, SwiftUI) içeride ne yaptığını denetlemez.
# Uygulama App Sandbox ile imzalanmadığı için ağsızlık işletim sistemi tarafından zorlanmaz.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
APP_NAME=${APP_NAME:-Beyin}
TARGET=${1:-}

FAILS=0
fail() { echo "  ✗ $*"; FAILS=$((FAILS + 1)); }
ok() { echo "  ✓ $*"; }
note() { echo "  · $*"; }

# MARK: Hedef ikili

APP=""
if [[ -z "$TARGET" ]]; then
  echo "Release derleniyor…"
  (cd "$ROOT" && swift build -c release >/dev/null)
  BINARY="$(cd "$ROOT" && swift build -c release --show-bin-path)/$APP_NAME"
elif [[ -d "$TARGET" && "$TARGET" == *.app ]]; then
  APP=$(cd "$TARGET" && pwd)
  BINARY="$APP/Contents/MacOS/$APP_NAME"
else
  BINARY="$TARGET"
fi
if [[ ! -f "$BINARY" ]]; then
  echo "İkili bulunamadı: $BINARY" >&2
  exit 2
fi
echo "İkili: $BINARY"

# MARK: 1. Kaynak kodu

# Yorum satırları (// ve ///) atlanır: belge yorumlarındaki bağlantılar kod değildir.
source_grep() {
  grep -rnE --include='*.swift' "$1" "$ROOT/Sources" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true
}

if [[ -d "$ROOT/Sources" ]]; then
  echo
  echo "1. Kaynak kodu (Sources/)"

  # Ağ API'leri. Foundation'ın URL tipi tek başına aranmaz: Beyin onu dosya yolları ve obsidian:// bağlantısı
  # için kullanır. Uzak adres ancak bir http(s) metniyle oluşabileceği için "http://" ve "https://" ayrıca aranır.
  # Data(contentsOf:)/String(contentsOf:) de bu yüzden aranmaz; dosya URL'siyle yalnız diskten okurlar.
  # dlopen/dlsym ağ işlevlerini adla çağırmanın yoludur; ikilide derleyicinin kendi kullanımı olduğundan (aşağıda)
  # kaynakta aranır.
  NET_SRC='import[[:space:]]+(Network|WebKit|SafariServices|AuthenticationServices|CFNetwork)\b|URLSession|URLRequest|NSURLConnection|NSURLDownload|NWConnection|NWListener|NWBrowser|NWPathMonitor|nw_[a-z_]+\(|WKWebView|WebView\b|AsyncImage|CFSocket|CFStream|CFHTTP|CFHost|getaddrinfo|gethostbyname|\bsocket\(|SCNetworkReachability|Sparkle|SUUpdater|Analytics|Telemetry|Crashlytics|Sentry|"https?://|dlopen|dlsym'
  hits=$(source_grep "$NET_SRC")
  if [[ -n "$hits" ]]; then
    fail "Ağa çıkabilecek kod:"
    echo "$hits" | sed "s|$ROOT/||; s/^/      /"
  else
    ok "Ağ API'si, web görünümü, güncelleyici, analitik ya da http(s) adresi yok."
  fi

  # Dosya yazma, taşıma, silme. UserDefaults (seçili kasa yolu ve görünüm ayarları) kasanın dışında,
  # ~/Library/Preferences'ta tutulur; aranmaz.
  WRITE_SRC='write\(to|\.write\(|createFile|removeItem|moveItem|copyItem|replaceItem|trashItem|linkItem|createDirectory|createSymbolicLink|setAttributes|FileHandle\(for(Writing|Updating)|fopen\(|unlink\(|rename\(|NSFileCoordinator'
  hits=$(source_grep "$WRITE_SRC")
  if [[ -n "$hits" ]]; then
    fail "Diske yazabilecek kod:"
    echo "$hits" | sed "s|$ROOT/||; s/^/      /"
  else
    ok "Dosya yazma, taşıma ya da silme çağrısı yok."
  fi

  # Uygulama dışına açılan bağlantılar bilgi olarak listelenir (hata sayılmaz): obsidian:// ve Finder.
  hits=$(source_grep 'NSWorkspace|\.open\(|openURL|OpenURLAction')
  if [[ -n "$hits" ]]; then
    note "Başka uygulamaya devredilen açma işlemleri (elle gözden geçir):"
    echo "$hits" | sed "s|$ROOT/||; s/^/      /"
  fi
fi

# MARK: 2. Bağlı çerçeveler

echo
echo "2. Bağlı çerçeveler (otool -L)"
# Doğrudan bağlılıklar. Foundation kendi içinde CFNetwork'ü kullanır; burada aranan, uygulamanın ağ ya da web
# çerçevesine kendisinin bağlanıp bağlanmadığı.
hits=$(otool -L "$BINARY" | grep -E '/(Network|CFNetwork|WebKit|SafariServices|AuthenticationServices|JavaScriptCore)\.framework/|libswiftNetwork|libnetwork' || true)
if [[ -n "$hits" ]]; then
  fail "Ağ/web çerçevesine bağlı:"
  echo "$hits" | sed 's/^/      /'
else
  ok "Network, CFNetwork, WebKit ya da benzeri bir çerçeveye doğrudan bağlı değil."
fi

# MARK: 3. Dışarıdan çağrılan semboller

echo
echo "3. Dışarıdan çağrılan semboller (nm -u)"
# Swift sembolleri biçimlendirilmiş (mangled) adlarla gelir; URLSession, AsyncImage gibi adlar içlerinde düz geçer.
# Swift'ten çağrılan Foundation URLSession'ı da "So12NSURLSessionC" olarak burada görünür.
# C sembolleri tam adla eşleşir (_connect, _socket…); "connect" geçen başka adlar böylece yanlış pozitif vermez.
# İkilide _fopen/_fread/_dlsym bulunur: derleyicinin #available kontrolü (__isPlatformVersionAtLeast)
# /System/Library/CoreServices/SystemVersion.plist dosyasını okumak için bunları kullanır. Bu yüzden burada aranmaz.
SYMS=$(nm -u "$BINARY" 2>/dev/null | grep -v '^$' || true)
hits=$( (grep -E 'URLSession|NSURLConnection|NSURLDownload|URLRequest|NSURLRequest|AsyncImage|WKWebView|WebView|_nw_|NWConnection|NWListener|NWPathMonitor|SCNetworkReachability|_CFSocket|_CFStream.*Socket|_CFHTTP|_CFHost' <<<"$SYMS";
          grep -xE '_(socket|connect|bind|listen|accept|sendto|recvfrom|sendmsg|recvmsg|getaddrinfo|gethostbyname|gethostbyname2|getnameinfo)' <<<"$SYMS") || true)
if [[ -n "$hits" ]]; then
  fail "Ağ sembolü çağrılıyor:"
  sort -u <<<"$hits" | sed 's/^/      /'
else
  ok "URLSession, Network.framework (nw_*), soket ya da DNS sembolü yok."
fi

# Yazma, Swift tarafı: Data.write(to:) ve String.write(toFile:) gibi yöntemler biçimlendirilmiş adla görünür
# ("5write2to", "5write6toFile"). TextOutputStream'in write(to:) yöntemi ("SJ5write2to", print/string
# birleştirme) dosyaya yazmaz; ayıklanır. C tarafı tam adla eşleşir.
hits=$( (grep -E '5write(2to|6toFile)' <<<"$SYMS" | grep -vE 'SJ5write2to|TextOutputStream';
          grep -xE '_(write|fwrite|pwrite|unlink|unlinkat|rename|renameat|mkdir|rmdir|truncate|ftruncate|creat|symlink|link|copyfile|clonefile|removefile)' <<<"$SYMS") || true)

# Yazma, Objective-C tarafı: FileManager ve NSData yöntemleri nm'de değil, seçici (selector) adı olarak
# __objc_methname bölümünde görünür. Adların başı eşleşir; "setCanCreateDirectories:" (Klasör seç penceresinde
# yeni klasör düğmesini kapatır) ve "removeObserver:" gibi adlar böylece yanlış pozitif vermez.
SELECTORS=$(otool -v -s __TEXT __objc_methname "$BINARY" 2>/dev/null | awk 'NF >= 2 {print $2}' || true)
hits+=$'\n'$(grep -E '^(writeTo(URL|File):|createFileAt|removeItemAt|moveItemAt|copyItemAt|replaceItemAt|trashItemAt|createDirectoryAt|createSymbolicLinkAt|linkItemAt|setAttributes:ofItemAtPath|fileHandleForWriting|fileHandleForUpdating|initForWriting|initForUpdating)' <<<"$SELECTORS" || true)
hits=$(grep -v '^$' <<<"$hits" || true)
if [[ -n "$hits" ]]; then
  fail "Dosya yazma sembolü ya da seçicisi var:"
  sort -u <<<"$hits" | sed 's/^/      /'
else
  ok "Dosya yazma, taşıma ya da silme sembolü/seçicisi yok."
fi

# Ağ, Objective-C tarafı: NSURLSession/NSURLConnection yöntem adları.
hits=$(grep -E '^(dataTaskWith|downloadTaskWith|uploadTaskWith|webSocketTaskWith|streamTaskWith|sharedSession$|sessionWithConfiguration|sendSynchronousRequest|sendAsynchronousRequest|connectionWithRequest|loadRequest:|loadHTMLString)' <<<"$SELECTORS" || true)
if [[ -n "$hits" ]]; then
  fail "Ağ seçicisi var:"
  sort -u <<<"$hits" | sed 's/^/      /'
else
  ok "NSURLSession/NSURLConnection/web görünümü seçicisi yok."
fi

# MARK: 4. İkilideki metinler

echo
echo "4. İkilideki adresler (strings)"
# Apple'ın plist DTD adresi bir istek değil, belge türü bildirimidir; ayıklanır.
hits=$(strings -a "$BINARY" | grep -E 'https?://' | grep -vE '^https?://www\.apple\.com/DTDs/' || true)
if [[ -n "$hits" ]]; then
  fail "İkilide http(s) adresi var:"
  sort -u <<<"$hits" | head -20 | sed 's/^/      /'
else
  ok "İkilide http(s) adresi yok."
fi

# MARK: 5. Uygulama paketi

if [[ -n "$APP" ]]; then
  echo
  echo "5. Uygulama paketi ($(basename "$APP"))"
  ents=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)
  if grep -qE 'com\.apple\.security\.network\.(client|server)' <<<"$ents"; then
    fail "Yetkilerde ağ izni var (com.apple.security.network.*)."
  else
    ok "Yetkilerde ağ izni yok."
  fi
  if grep -q 'com.apple.security.app-sandbox' <<<"$ents"; then
    note "App Sandbox açık."
  else
    note "App Sandbox kapalı: ağsızlık macOS tarafından zorlanmaz, yukarıdaki kod kontrollerine dayanır."
  fi

  PLIST="$APP/Contents/Info.plist"
  hits=$(plutil -p "$PLIST" | grep -E 'NSAppTransportSecurity|NSAllowsArbitraryLoads|SUFeedURL|SUPublicEDKey|NSBonjourServices|NSLocalNetworkUsageDescription' || true)
  if [[ -n "$hits" ]]; then
    fail "Info.plist ağ ya da güncelleyici anahtarı içeriyor:"
    echo "$hits" | sed 's/^/      /'
  else
    ok "Info.plist'te ağ, Bonjour ya da güncelleyici anahtarı yok."
  fi

  shopt -s nullglob
  embedded=("$APP/Contents/Frameworks/"* "$APP/Contents/PlugIns/"* "$APP/Contents/XPCServices/"*)
  shopt -u nullglob
  if [[ ${#embedded[@]} -gt 0 ]]; then
    fail "Pakete gömülü çerçeve/eklenti var (ayrıca denetlenmeli):"
    printf '      %s\n' "${embedded[@]#"$APP/"}"
  else
    ok "Gömülü üçüncü taraf çerçeve, eklenti ya da XPC servisi yok."
  fi
fi

echo
if [[ $FAILS -gt 0 ]]; then
  echo "SONUÇ: $FAILS kontrol şüpheli buldu."
  exit 1
fi
echo "SONUÇ: Şüpheli bir şey bulunmadı."
