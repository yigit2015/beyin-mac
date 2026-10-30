import Foundation

/// Notun başındaki `---` blokları: JSON ya da avenoxbeyin'in kabul ettiği düz YAML (docs/v3/MARKDOWN.md).
struct Frontmatter: Equatable {
    var fields: [String: String] = [:]
    var tags: [String] = []

    var kind: String? { fields["kind"].map { $0.lowercased() } }
    var title: String? { fields["title"] }
    var project: String? { fields["project"]?.trimmingCharacters(in: .whitespaces).nonEmpty }
    /// tarih / date / created / created_at: "2026-10-06", "2026-10-06T01:21:14" ya da ISO 8601.
    var date: Date? { firstDate(["tarih", "date", "created", "created_at"]) }
    /// Obsidian'ın yaygın güncelleme anahtarları; yoksa dosyanın değişme zamanı kullanılır.
    var modified: Date? { firstDate(["updated_at", "updated", "modified", "last_modified", "date_modified"]) }

    /// `kind: receipt` ya da `generated: true`: ajanın ürettiği kayıt, upstream de indekslemez.
    var isGenerated: Bool { kind == "receipt" || fields["generated"]?.lowercased() == "true" }
    /// Bir değer tam olarak yer tutucuysa (`created: {{TODAY}}`) bu bir şablondur.
    var isTemplate: Bool { fields.values.contains(where: SourceRules.isPlaceholder) }

    /// public ve internal gösterilir; private ve tanınmayan değerlerin içeriği gizlenir.
    var visibility: Visibility {
        guard let raw = fields["visibility"]?.trimmingCharacters(in: .whitespaces).lowercased(), !raw.isEmpty
        else { return .internal }
        return raw == "public" || raw == "internal" ? .internal : .private
    }

    private func firstDate(_ keys: [String]) -> Date? {
        for key in keys {
            guard let raw = fields[key]?.trimmingCharacters(in: .whitespaces), raw.count >= 10 else { continue }
            if let full = try? Date(raw, strategy: .iso8601) { return full }
            let local = DateFormatter()
            local.locale = Locale(identifier: "en_US_POSIX")
            local.timeZone = .current
            for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
                local.dateFormat = format
                if let parsed = local.date(from: String(raw.prefix(format.replacingOccurrences(of: "'", with: "").count))) {
                    return parsed
                }
            }
        }
        return nil
    }

    /// Dosya metnini frontmatter ve gövde olarak ayırır.
    static func split(_ text: String) -> (Frontmatter, body: Substring) {
        let full = Substring(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        guard full.hasPrefix("---") else { return (Frontmatter(), full) }
        let afterOpen = full.dropFirst(3)
        guard let firstNewline = afterOpen.firstIndex(of: "\n"),
              afterOpen[..<firstNewline].allSatisfy({ $0 == " " || $0 == "\r" }) else { return (Frontmatter(), full) }
        let rest = afterOpen[afterOpen.index(after: firstNewline)...]
        // Kapanış: kendi satırında duran "---".
        var lineStart = rest.startIndex
        while lineStart < rest.endIndex {
            let lineEnd = rest[lineStart...].firstIndex(of: "\n") ?? rest.endIndex
            if rest[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces) == "---" {
                let header = rest[rest.startIndex..<lineStart]
                let body = lineEnd < rest.endIndex ? rest[rest.index(after: lineEnd)...] : rest[rest.endIndex...]
                return (parse(String(header)), body)
            }
            lineStart = lineEnd < rest.endIndex ? rest.index(after: lineEnd) : rest.endIndex
        }
        return (Frontmatter(), full)
    }

    static func parse(_ header: String) -> Frontmatter {
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return fromJSON(object)
        }
        return fromYAML(trimmed)
    }

    private static func fromJSON(_ object: [String: Any]) -> Frontmatter {
        var result = Frontmatter()
        for (key, value) in object {
            switch value {
            case let string as String: result.fields[key] = string
            case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
                result.fields[key] = number.boolValue ? "true" : "false"
            case let number as NSNumber: result.fields[key] = number.stringValue
            case let list as [Any] where key == "tags":
                result.tags = list.compactMap { $0 as? String }
            default: continue
            }
        }
        return result
    }

    /// Düz `anahtar: değer`, `[a, "b c"]` ve girintili `- öğe` listeleri; satır sonu `# yorum`
    /// atılır, `# kind: x` gibi yorum satırları okunmaz. İç içe yapılar desteklenmez, atlanır.
    private static func fromYAML(_ text: String) -> Frontmatter {
        var result = Frontmatter()
        var listKey: String?
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.replacingOccurrences(of: "\r", with: "")
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.hasPrefix("#") { continue }
            if stripped.hasPrefix("- ") || stripped == "-", let key = listKey {
                let item = scalar(String(stripped.dropFirst()))
                if key == "tags", !item.isEmpty { result.tags.append(item) }
                continue
            }
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"), let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = scalar(String(line[line.index(after: colon)...]))
            listKey = value.isEmpty ? key : nil
            guard !value.isEmpty, value != ">", value != "|" else { continue }
            if value.hasPrefix("["), value.hasSuffix("]"), !SourceRules.isPlaceholder(value) {
                if key == "tags" { result.tags = inlineList(value) }
                continue
            }
            result.fields[key] = value
        }
        return result
    }

    /// Tek değer: tırnaklıysa açılır (çift tırnakta JSON kaçışları, tek tırnakta `''`), değilse
    /// boşlukla başlayan `#` sonrası yorumdur.
    private static func scalar(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard let quote = text.first, quote == "\"" || quote == "'" else {
            if text.hasPrefix("#") { return "" }
            if let comment = text.range(of: #"\s#"#, options: .regularExpression) {
                return String(text[..<comment.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return text
        }
        var index = text.index(after: text.startIndex)
        var escaped = false
        while index < text.endIndex {
            let char = text[index]
            if quote == "\"", char == "\\", !escaped { escaped = true; index = text.index(after: index); continue }
            if char == quote, !escaped {
                let next = text.index(after: index)
                if quote == "'", next < text.endIndex, text[next] == "'" { index = text.index(after: next); continue }
                let rest = text[next...].trimmingCharacters(in: .whitespaces)
                guard rest.isEmpty || rest.hasPrefix("#") else { return text }
                return unquote(String(text[...index]))
            }
            escaped = false
            index = text.index(after: index)
        }
        return text
    }

    private static func unquote(_ quoted: String) -> String {
        if quoted.hasPrefix("\""), let data = quoted.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }
        return String(quoted.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
    }

    /// `[a, "b, c"]`: tamamı geçerli JSON ise JSON olarak, değilse tırnak farkında virgülle bölünür.
    private static func inlineList(_ value: String) -> [String] {
        if let data = value.data(using: .utf8), let list = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return list.compactMap { $0 as? String }
        }
        var items: [String] = []
        var current = ""
        var quote: Character?
        for char in value.dropFirst().dropLast() {
            if let open = quote {
                if char == open { quote = nil }
            } else if char == "\"" || char == "'" {
                quote = char
            } else if char == "," {
                items.append(current)
                current = ""
                continue
            }
            current.append(char)
        }
        items.append(current)
        return items.map(scalar).filter { !$0.isEmpty }
    }
}

enum Wikilinks {
    /// `[[hedef]]`, `[[hedef|ad]]`, `[[hedef#başlık]]`, `![[gömülü]]` → "hedef".
    static func extract(from text: Substring) -> [String] {
        var links: [String] = []
        var index = text.startIndex
        while let open = text[index...].range(of: "[[") {
            guard let close = text[open.upperBound...].range(of: "]]") else { break }
            let inner = text[open.upperBound..<close.lowerBound]
            index = close.upperBound
            guard !inner.contains("\n"), !inner.contains("[") else { continue }
            var target = Substring(inner)
            if let bar = target.firstIndex(of: "|") { target = target[..<bar] }
            if let hash = target.firstIndex(of: "#") { target = target[..<hash] }
            if let caret = target.firstIndex(of: "^") { target = target[..<caret] }
            let cleaned = target.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty { links.append(cleaned) }
        }
        return links
    }

    /// Ada göre çözüm anahtarı: son yol parçası, .md'siz, küçük harf, Unicode NFC
    /// (macOS'un NFD dosya adı da elle yazılmış bağlantıyla eşleşir; MARKDOWN.md ile aynı kural).
    static func key(for target: String) -> String {
        var name = (target as NSString).lastPathComponent.precomposedStringWithCanonicalMapping
        if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }
        return name.lowercased()
    }
}

/// Kasanın düzeni: avenoxbeyin (companion klasörü ya da `.beyin-runtime.json` var) ya da herhangi bir Obsidian kasası.
public enum VaultLayout: Sendable {
    case avenox, generic
}

enum Categorizer {
    struct Placement: Equatable {
        var category: NoteCategory
        var project: String?
        var subcluster: String?
    }

    /// Notun yeri. Önce keşfedilen çekirdek klasörü, sonra frontmatter (`kind`, `project`);
    /// klasör adları (`projects/`, `🏰 300-Projects/`, `daily/`…) yalnız yedek ipucudur.
    /// Genel kasada üst klasör küme olur.
    static func place(relativePath path: String, kind: String?, project frontProject: String? = nil,
                      context: VaultContext = .avenox) -> Placement {
        let parts = path.split(separator: "/").map(String.init)
        let top = parts.first ?? ""
        if parts.count >= 2, let companion = context.companion, SourceRules.dirKey(top) == SourceRules.dirKey(companion) {
            return Placement(category: .core)
        }
        let folder: (project: String, sub: String?)? = isProjectsRoot(top) && parts.count >= 3
            ? (parts[1], parts.count >= 4 ? parts[2] : nil) : nil
        if let kind, let byKind = category(forKind: kind) {
            return Placement(category: byKind, project: folder?.project ?? frontProject)
        }
        if let folder {
            let category: NoteCategory = folder.project == "sohbet-arsivi" ? .chat : .project
            return Placement(category: category, project: folder.project, subcluster: folder.sub)
        }
        if let frontProject {
            return Placement(category: frontProject == "sohbet-arsivi" ? .chat : .project, project: frontProject)
        }
        switch SourceRules.dirKey(top) {
        case "daily" where parts.count >= 2: return Placement(category: .daily)
        case "tasks" where parts.count >= 2: return Placement(category: .task)
        case "notes" where parts.count >= 3 && SourceRules.dirKey(parts[1]) == "kisiler": return Placement(category: .person)
        default:
            guard context.layout == .generic, parts.count >= 2 else { return Placement(category: .fact) }
            return Placement(category: .project, project: top, subcluster: parts.count >= 3 ? parts[1] : nil)
        }
    }

    /// `projects` ya da resmi şablondaki `🏰 300-Projects`: emoji ve sıra numarası öneki yok sayılır.
    static func isProjectsRoot(_ name: String) -> Bool {
        var key = Substring(SourceRules.dirKey(name))
        key = key.drop { !$0.isLetter && !$0.isNumber }
        key = key.drop(while: \.isNumber)
        if key.hasPrefix("-") { key = key.dropFirst() }
        return key == "projects"
    }

    private static func category(forKind kind: String) -> NoteCategory? {
        switch kind {
        case "fact": .fact
        case "person": .person
        case "task": .task
        case "daily": .daily
        default: nil
        }
    }
}
