import Foundation

/// Hangi dosyaların not sayılacağı. avenoxbeyin'in V3 tarayıcısıyla aynı kurallar
/// (docs/v3/MARKDOWN.md, beyin_v3_sync.py): hiçbir klasörün var olduğu varsayılmaz,
/// adla atlanan yalnız aşağıdakilerdir.
enum SourceRules {
    static let excludedDirs: Set<String> = ["node_modules", "receipts", "__pycache__"]
    /// Ajan talimatı ve ayar dosyaları; her derinlikte, büyük/küçük harf duyarsız.
    static let excludedFiles: Set<String> = [
        "agents.md", "claude.md", "gemini.md", "skill.md", "hooks.md", "config.md", "settings.md",
        "instructions.md", "codex.md", "setup.md", "install.md",
    ]

    static func isExcludedFile(_ name: String) -> Bool {
        let key = name.lowercased()
        return excludedFiles.contains(key) || key.hasPrefix("setup-")
    }

    /// Klasör adı karşılaştırma anahtarı: NFC, küçük harf; Türkçe İ/ı/I/i tek harf (beyin_v3_index.dir_key).
    static func dirKey(_ name: String) -> String {
        let nfc = name.precomposedStringWithCanonicalMapping
        if nfc.allSatisfy(\.isASCII) { return nfc.lowercased() }
        let dotless = nfc.replacingOccurrences(of: "\u{130}", with: "i").replacingOccurrences(of: "\u{131}", with: "i")
        let scalars = dotless.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars
        var folded = String.UnicodeScalarView()
        var previous: Unicode.Scalar?
        for scalar in scalars {
            if scalar == "\u{307}", previous == "i" { continue }
            folded.append(scalar)
            previous = scalar
        }
        return String(folded).precomposedStringWithCanonicalMapping
    }

    /// Kasa sınıfı klasörler (kasa, şifre, müşteri, private…): upstream bunları hiç indekslemez,
    /// Beyin de göstermez. Kelime bazlı eşleşme: "🔐 Kasa", "410-Şifreler", NFD "MÜŞTERİLER".
    static func isSensitive(_ name: String) -> Bool {
        let words = sensitiveFold(name).split { !$0.isLetter }
        return words.contains { word in
            let text = String(word)
            let range = NSRange(text.startIndex..., in: text)
            return sensitiveWord.firstMatch(in: text, range: range).map { $0.range == range } ?? false
        }
    }

    private static let sensitiveWord = try! NSRegularExpression(pattern:
        "(?:kasa|sifre|parola|kimlik|kimlig|finans|finansal|musteri|vergi|fatura|maas|ozel|gizli|gizlilik)"
        + "(?:ler|lar)?(?:i|im|in|imiz|leri|lari)?"
        + "|(?:private|secret|password|credential)s?")

    private static let asciiFold: [Character: Character] = [
        "ş": "s", "ğ": "g", "ü": "u", "ö": "o", "ç": "c", "ı": "i", "â": "a", "î": "i", "û": "u",
    ]

    private static func sensitiveFold(_ name: String) -> String {
        let lowered = name.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "İ", with: "i").replacingOccurrences(of: "I", with: "i").lowercased()
        let scalars = lowered.decomposedStringWithCanonicalMapping.unicodeScalars.filter { $0 != "\u{307}" }
        let nfc = String(String.UnicodeScalarView(scalars)).precomposedStringWithCanonicalMapping
        return String(nfc.map { asciiFold[$0] ?? $0 })
    }

    /// Şablon notu: frontmatter değeri tam olarak yer tutucu (`{{TODAY}}`, Templater `<% … %>`).
    /// Gerçek bir notta bu değer kalmaz; şablon klasörünü adından tahmin etmek gerekmez.
    static func isPlaceholder(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespaces)
        return (text.hasPrefix("{{") && text.hasSuffix("}}")) || (text.hasPrefix("<%") && text.hasSuffix("%>"))
    }
}

/// Kasadan keşfedilen düzen: çekirdek klasörü, şablon klasörleri, kullanıcının dışladığı klasörler.
public struct VaultContext: Sendable, Equatable {
    var layout: VaultLayout
    /// Kökteki companion klasörünün adı; bulunamadıysa ya da birden çok aday varsa nil.
    var companion: String?
    /// Obsidian ayarındaki şablon klasörleri, kasa köküne göre (NFC).
    var templateFolders: Set<String> = []
    /// avenoxbeyin runtime'ındaki `index.json` `excluded_dirs` adları (dirKey ile).
    var excludedDirKeys: Set<String> = []

    static let defaultCompanion = "🔮 850-Companion"
    static let avenox = VaultContext(layout: .avenox, companion: defaultCompanion)
    static let generic = VaultContext(layout: .generic, companion: nil)

    static func discover(in root: URL) -> VaultContext {
        let companion = companionFolder(in: root)
        let fm = FileManager.default
        let isAvenox = companion != nil || fm.fileExists(atPath: root.appending(path: ".beyin-runtime.json").path)
        return VaultContext(
            layout: isAvenox ? .avenox : .generic,
            companion: companion,
            templateFolders: templateFolders(in: root),
            excludedDirKeys: userExcludedDirKeys(in: root, companion: companion))
    }

    /// beyin_v3_companion.directory ile aynı: adı "companion"/"echo" ile biten klasör, yoksa
    /// Core.md ya da Soul.md taşıyan klasör. Arşiv adlılar sayılmaz; iki aday arasında seçim yapılmaz.
    static func companionFolder(in root: URL) -> String? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        else { return nil }
        var named: [String] = []
        var candidates: [String] = []
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            let name = entry.lastPathComponent
            let lowered = name.precomposedStringWithCanonicalMapping.lowercased()
            if ["archive", "arşiv", "arsiv"].contains(where: { lowered.contains($0) }) { continue }
            if name.precomposedStringWithCanonicalMapping == defaultCompanion
                || lowered.hasSuffix("companion") || lowered.hasSuffix("echo") {
                named.append(name)
            } else if ["Core.md", "Soul.md"].contains(where: { fm.fileExists(atPath: entry.appending(path: $0).path) }) {
                candidates.append(name)
            }
        }
        let pick = named.isEmpty ? candidates : named
        return pick.count == 1 ? pick[0] : nil
    }

    /// Obsidian'ın Şablonlar eklentisi (`.obsidian/templates.json` → folder) ve Templater
    /// (`templates_folder`) ayarları. Ayar yoksa hiçbir klasör şablon sayılmaz.
    static func templateFolders(in root: URL) -> Set<String> {
        let sources = [
            (".obsidian/templates.json", "folder"),
            (".obsidian/plugins/templater-obsidian/data.json", "templates_folder"),
        ]
        var result: Set<String> = []
        for (path, key) in sources {
            guard let data = try? Data(contentsOf: root.appending(path: path)),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let folder = object[key] as? String else { continue }
            let trimmed = folder.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            if !trimmed.isEmpty { result.insert(trimmed.precomposedStringWithCanonicalMapping) }
        }
        return result
    }

    /// `.beyin-runtime.json` → state klasörü → `index.json` (beyin_v3_index.read/check).
    /// Dosya yoksa ya da geçersizse hiçbir şey dışlanmaz; upstream de o zaman her şeyi indeksler.
    static func userExcludedDirKeys(in root: URL, companion: String?) -> Set<String> {
        guard let runtimeData = try? Data(contentsOf: root.appending(path: ".beyin-runtime.json")),
              let runtime = try? JSONSerialization.jsonObject(with: runtimeData) as? [String: Any],
              let statePath = (runtime["state"] as? String).map({ ($0 as NSString).expandingTildeInPath }),
              statePath.hasPrefix("/") else { return [] }
        let indexURL = URL(fileURLWithPath: statePath).appending(path: "index.json")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: indexURL.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? Int ?? .max) <= 65536,
              let data = try? Data(contentsOf: indexURL),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(value.keys).isSubset(of: ["schema", "excluded_dirs"]),
              (value["schema"] as? Int ?? 1) == 1,
              let names = (value["excluded_dirs"] ?? [Any]()) as? [String], names.count <= 64
        else { return [] }
        // Upstream geçersiz bir girdi görünce listenin tamamını reddeder; burada da öyle.
        let protected = Set((["knowledge", "notes", "tasks", defaultCompanion] + [companion].compactMap { $0 })
            .map(SourceRules.dirKey))
        var keys: Set<String> = []
        for name in names {
            guard !name.isEmpty, name == name.trimmingCharacters(in: .whitespaces), name.count <= 255,
                  !name.contains("/"), !name.contains("\\"), name != ".", name != "..",
                  !name.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return [] }
            let key = SourceRules.dirKey(name)
            if protected.contains(key) { return [] }
            keys.insert(key)
        }
        return keys.filter { !$0.hasPrefix(".") && !SourceRules.excludedDirs.contains($0) }
    }
}
