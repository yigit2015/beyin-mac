import Foundation

/// Notun başındaki `---` blokları. Beyin JSON yazar, eski Obsidian notları basit YAML kullanır.
struct Frontmatter: Equatable {
    var fields: [String: String] = [:]
    var tags: [String] = []

    var kind: String? { fields["kind"].map { $0.lowercased() } }
    var title: String? { fields["title"] }
    var project: String? { fields["project"] }
    /// tarih / date / created alanı: "2026-10-06", "2026-10-06T01:21:14" ya da ISO 8601.
    var date: Date? {
        for key in ["tarih", "date", "created"] {
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

    var visibility: Visibility {
        fields["visibility"]?.lowercased() == "private" ? .private : .internal
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
            case let number as NSNumber: result.fields[key] = number.stringValue
            case let list as [Any] where key == "tags":
                result.tags = list.compactMap { $0 as? String }
            default: continue
            }
        }
        return result
    }

    /// Yalnız düz `anahtar: değer`, `[a, b]` ve `- öğe` listeleri; bu kasa için yeterli.
    private static func fromYAML(_ text: String) -> Frontmatter {
        var result = Frontmatter()
        var listKey: String?
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.replacingOccurrences(of: "\r", with: "")
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.hasPrefix("- "), let key = listKey {
                let item = unquote(String(stripped.dropFirst(2)))
                if key == "tags" { result.tags.append(item) }
                continue
            }
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"), let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            listKey = value.isEmpty ? key : nil
            guard !value.isEmpty, value != ">", value != "|" else { continue }
            if value.hasPrefix("["), value.hasSuffix("]") {
                let items = value.dropFirst().dropLast().split(separator: ",").map { unquote(String($0)) }
                if key == "tags" { result.tags = items }
                continue
            }
            result.fields[key] = unquote(value)
        }
        return result
    }

    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2, let first = trimmed.first, first == trimmed.last, first == "\"" || first == "'" {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
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

    /// Obsidian gibi ada göre çözüm anahtarı: son yol parçası, .md'siz, küçük harf.
    static func key(for target: String) -> String {
        var name = (target as NSString).lastPathComponent
        if name.lowercased().hasSuffix(".md") { name = String(name.dropLast(3)) }
        return name.lowercased()
    }
}

/// Kasanın düzeni: avenoxbeyin (kökte "…Companion" klasörü var) ya da herhangi bir Obsidian kasası.
public enum VaultLayout: Sendable {
    case avenox, generic

    static func detect(in root: URL) -> VaultLayout {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.contains { $0.hasSuffix("Companion") } ? .avenox : .generic
    }
}

enum Categorizer {
    struct Placement: Equatable {
        var category: NoteCategory
        var project: String?
        var subcluster: String?
    }

    /// Yol ve `kind` alanından notun yeri. Genel kasada üst klasör, avenoxbeyin'in `projects/` klasörü gibi küme olur.
    static func place(relativePath path: String, kind: String?, layout: VaultLayout = .avenox) -> Placement {
        let parts = path.split(separator: "/").map(String.init)
        let top = parts.first ?? ""
        if top.hasSuffix("Companion") { return Placement(category: .core) }
        if top == "projects", parts.count >= 3 {
            let project = parts[1]
            let sub = parts.count >= 4 ? parts[2] : nil
            if project == "sohbet-arsivi" { return Placement(category: .chat, project: project, subcluster: sub) }
            return Placement(category: .project, project: project, subcluster: sub)
        }
        if let kind, let byKind = category(forKind: kind) { return Placement(category: byKind) }
        switch top {
        case "daily": return Placement(category: .daily)
        case "tasks": return Placement(category: .task)
        case "notes" where parts.count >= 3 && parts[1] == "kisiler": return Placement(category: .person)
        default:
            guard layout == .generic, parts.count >= 2 else { return Placement(category: .fact) }
            return Placement(category: .project, project: top, subcluster: parts.count >= 3 ? parts[1] : nil)
        }
    }

    private static func category(forKind kind: String) -> NoteCategory? {
        switch kind {
        case "person": .person
        case "task": .task
        case "daily": .daily
        default: nil
        }
    }
}
