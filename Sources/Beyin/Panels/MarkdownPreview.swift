import BeyinCore
import SwiftUI

/// `Note.excerpt` önizlemesi (Inceleme.dc.html · Önizleme): satır satır.
/// "# " başlık (14/18 Semibold), "- " / "* " madde, "- [ ]" görev, "1." numaralı satır, diğerleri paragraf (12.5/18).
/// Satır içi Markdown (kalın, italik, `kod`) AttributedString ile; [[hedef|ad]] wikilink'leri teal çip, tıklanınca o not seçilir.
struct MarkdownPreview: View {
    @Environment(\.palette) private var palette
    let text: String
    /// Wikilink tıklanınca çağrılır (hedef metniyle). nil ise wikilink'ler yalnız vurgulanır.
    var openLink: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(MarkdownLine.parse(text).enumerated()), id: \.offset) { _, line in
                row(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == WikiInline.scheme, let target = WikiInline.target(from: url) else { return .systemAction }
            openLink?(target)
            return .handled
        })
    }

    @ViewBuilder
    private func row(_ line: MarkdownLine) -> some View {
        switch line {
        case .heading(let content):
            Text(inline(content))
                .font(BeyinFont.headline)
                .foregroundStyle(palette.t1)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case .bullet(let content):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•").foregroundStyle(palette.t3)
                paragraph(content)
            }
            .padding(.leading, 4)
        case .ordered(let number, let content):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").monospacedDigit().foregroundStyle(palette.t3)
                paragraph(content)
            }
            .padding(.leading, 2)
        case .task(let done, let content):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TaskBox(done: done)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                paragraph(content)
                    .strikethrough(done, color: palette.t3)
                    .opacity(done ? 0.7 : 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(done ? "tamamlandı" : "açık")
        case .paragraph(let content):
            paragraph(content)
        }
    }

    private func paragraph(_ content: String) -> some View {
        Text(inline(content))
            .font(BeyinFont.callout)
            .lineSpacing(5.5)
            .foregroundStyle(palette.t2)
            .tint(palette.teal)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func inline(_ content: String) -> AttributedString {
        WikiInline.attributed(content, palette: palette, linksEnabled: openLink != nil)
    }
}

extension VaultGraph {
    /// Wikilink hedefini nota çözer: yol, dosya adı ya da başlık (büyük/küçük harf duyarsız); "#başlık" kısmı atılır.
    func resolveWikilink(_ target: String) -> Note? {
        let base = target.split(separator: "#", maxSplits: 1).first.map(String.init) ?? target
        let key = base.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        if let exact = notes[key] ?? notes[key + ".md"] { return exact }
        let lowered = key.lowercased()
        return notes.values.first { note in
            let stem = (note.id as NSString).lastPathComponent.lowercased()
            return stem == lowered + ".md" || note.title.lowercased() == lowered || note.id.lowercased() == lowered + ".md"
        }
    }
}

/// Önizleme satırı türleri.
enum MarkdownLine: Equatable {
    case heading(String)
    case bullet(String)
    case ordered(Int, String)
    case task(done: Bool, String)
    case paragraph(String)

    static func parse(_ text: String) -> [MarkdownLine] {
        text.split(separator: "\n", omittingEmptySubsequences: true).map { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                let heading = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                return heading.isEmpty ? .paragraph(line) : .heading(heading)
            }
            for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
                let rest = String(line.dropFirst(marker.count))
                let lower = rest.lowercased()
                if lower.hasPrefix("[ ] ") { return .task(done: false, String(rest.dropFirst(4))) }
                if lower.hasPrefix("[x] ") { return .task(done: true, String(rest.dropFirst(4))) }
                return .bullet(rest)
            }
            if let dot = line.firstIndex(of: "."), let number = Int(line[..<dot]), line[line.index(after: dot)...].hasPrefix(" ") {
                return .ordered(number, line[line.index(dot, offsetBy: 2)...].trimmingCharacters(in: .whitespaces))
            }
            return .paragraph(line)
        }
    }
}

/// Görev kutusu: 14×14, köşe 4; tamamlanınca günlük rengiyle dolu ve tikli (GenelBakis.dc.html `.task`).
private struct TaskBox: View {
    @Environment(\.palette) private var palette
    let done: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(done ? NoteCategory.daily.color(palette) : palette.t3, lineWidth: 1.5)
            .background(done ? NoteCategory.daily.color(palette) : .clear, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                if done {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                }
            }
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }
}

/// Satır içi Markdown + wikilink. Wikilink'ler önce özel şemalı Markdown bağlantısına çevrilir, ayrıştırmadan sonra
/// teal çip olarak boyanır; böylece **kalın [[not]]** gibi iç içe yazımlar da korunur. Ayrıştırma başarısızsa düz metin.
enum WikiInline {
    static let scheme = "beyin-wiki"
    /// Bağlantı hedefi yalnız ASCII harf/rakam bırakılarak kodlanır (Türkçe harfler de yüzde kodlanır).
    private static let asciiAlphanumerics = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    static func attributed(_ text: String, palette: Palette, linksEnabled: Bool = false) -> AttributedString {
        let source = rewriteWikilinks(in: text)
        var result: AttributedString
        if let parsed = try? AttributedString(markdown: source,
                                              options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            result = parsed
        } else {
            return plainFallback(text, palette: palette)
        }
        for run in result.runs {
            let range = run.range
            if let url = run.link, url.scheme == scheme {
                result[range].foregroundColor = palette.teal
                result[range].backgroundColor = palette.tealFill
                if !linksEnabled { result[range].link = nil }
            } else if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                // Token: mono 11.5, çip dolgusu (Inceleme.dc.html `.code`).
                result[range].font = BeyinFont.mono
                result[range].backgroundColor = palette.chip
                result[range].foregroundColor = palette.t1
            }
        }
        return result
    }

    static func target(from url: URL) -> String? {
        let raw = url.absoluteString.dropFirst(scheme.count + 1)
        return String(raw).removingPercentEncoding
    }

    /// `[[hedef|ad]]` → `[ad](beyin-wiki:hedef)`; görünen metin ad varsa ad, yoksa hedef (#başlık kısmı atılır).
    private static func rewriteWikilinks(in text: String) -> String {
        var output = ""
        var rest = Substring(text)
        while let open = rest.range(of: "[["), let close = rest[open.upperBound...].range(of: "]]") {
            output += rest[..<open.lowerBound]
            let inner = rest[open.upperBound..<close.lowerBound]
            let parts = inner.split(separator: "|", maxSplits: 1).map(String.init)
            let target = parts.first ?? String(inner)
            var label = parts.count > 1 ? parts[1] : target
            if parts.count == 1, let hash = label.firstIndex(of: "#"), hash != label.startIndex {
                label = String(label[..<hash])
            }
            let escapedLabel = label.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
            let encoded = target.addingPercentEncoding(withAllowedCharacters: asciiAlphanumerics) ?? target
            output += "[\u{2009}\(escapedLabel)\u{2009}](\(scheme):\(encoded))"
            rest = rest[close.upperBound...]
        }
        output += rest
        return output
    }

    /// Ayrıştırılamayan satır: yalnız wikilink'ler boyanır, gerisi düz metin.
    private static func plainFallback(_ text: String, palette: Palette) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(text)
        while let open = rest.range(of: "[["), let close = rest[open.upperBound...].range(of: "]]") {
            result += AttributedString(String(rest[..<open.lowerBound]))
            let inner = rest[open.upperBound..<close.lowerBound]
            let label = inner.split(separator: "|").last.map(String.init) ?? String(inner)
            var link = AttributedString("\u{2009}\(label)\u{2009}")
            link.foregroundColor = palette.teal
            link.backgroundColor = palette.tealFill
            result += link
            rest = rest[close.upperBound...]
        }
        result += AttributedString(String(rest))
        return result
    }
}
