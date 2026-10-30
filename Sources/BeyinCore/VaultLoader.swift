import Foundation

/// Kasayı diskten okur. Ağır iş ana iş parçacığının dışında yapılır.
public enum VaultLoader {
    public typealias Progress = @Sendable (Double, LoadPhase, LoadingCounts) -> Void

    public static func load(vaultURL: URL, progress: Progress? = nil) async -> LoadedVault {
        await Task.detached(priority: .userInitiated) {
            loadSync(vaultURL: vaultURL, progress: progress)
        }.value
    }

    public static func loadSync(vaultURL: URL, progress: Progress? = nil) -> LoadedVault {
        let context = VaultContext.discover(in: vaultURL)
        let files = markdownFiles(in: vaultURL, context: context)
        var notes: [Note] = []
        var bodies: [Note.ID: String] = [:]
        notes.reserveCapacity(files.count)
        for (offset, file) in files.enumerated() {
            if let (note, body) = readNote(file.url, relativePath: file.relativePath, context: context) {
                notes.append(note)
                if !note.isPrivate { bodies[note.id] = body }
            }
            if offset % 25 == 0 {
                progress?(Double(offset) / Double(max(files.count, 1)) * 0.8, .scanning,
                          LoadingCounts(scanned: offset, total: files.count))
            }
        }
        progress?(0.85, .resolving, LoadingCounts(scanned: files.count, total: files.count))
        let graph = GraphBuilder.build(notes: notes)
        let counts = LoadingCounts(scanned: files.count, total: files.count, resolvedLinks: graph.stats.linkCount)
        progress?(0.92, .layout, counts)
        let network = NetworkLayout.compute(graph)
        let sphere = SphereLayout.compute(graph)
        progress?(1, .layout, counts)
        return LoadedVault(graph: graph, index: SearchIndex(graph: graph, bodies: bodies), network: network, sphere: sphere)
    }

    struct FileEntry {
        let url: URL
        let relativePath: String
    }

    /// Not adayları. Atlama kuralları `SourceRules` ve `VaultContext`'te; sembolik bağlar izlenmez.
    static func markdownFiles(in root: URL, context: VaultContext? = nil) -> [FileEntry] {
        let context = context ?? VaultContext.discover(in: root)
        let rootPath = root.standardizedFileURL.path
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var result: [FileEntry] = []
        for case let url as URL in enumerator {
            let full = url.standardizedFileURL.path
            guard full.hasPrefix(rootPath + "/") else { continue }
            let relative = String(full.dropFirst(rootPath.count + 1))
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            let name = url.lastPathComponent
            if values?.isDirectory == true {
                let key = SourceRules.dirKey(name)
                if SourceRules.excludedDirs.contains(key) || SourceRules.isSensitive(name)
                    || context.excludedDirKeys.contains(key)
                    || context.templateFolders.contains(relative.precomposedStringWithCanonicalMapping) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard url.pathExtension.lowercased() == "md", !SourceRules.isExcludedFile(name) else { continue }
            result.append(FileEntry(url: url, relativePath: relative))
        }
        return result.sorted { $0.relativePath < $1.relativePath }
    }

    static func readNote(_ url: URL, relativePath: String, context: VaultContext) -> (Note, String)? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modified = attributes?[.modificationDate] as? Date ?? .distantPast
        let created = attributes?[.creationDate] as? Date
        return makeNote(text: text, relativePath: relativePath, modified: modified, created: created, context: context)
    }

    /// Dosya metninden Note üretir (testler diskten bağımsız çağırır). Makbuzlar, üretilmiş
    /// dosyalar (`kind: receipt`, `generated: true`) ve şablonlar not değildir: nil.
    static func makeNote(text: String, relativePath: String, modified: Date, created: Date?,
                         context: VaultContext = .avenox) -> (Note, String)? {
        let (front, body) = Frontmatter.split(text)
        guard !front.isGenerated, !front.isTemplate else { return nil }
        let placement = Categorizer.place(relativePath: relativePath, kind: front.kind, project: front.project,
                                          context: context)
        let fileTitle = ((relativePath as NSString).lastPathComponent as NSString).deletingPathExtension
        // Obsidian'da kimlik dosya adıdır. Yalnız "haftalik-ozet" gibi slug adlı notlarda ilk H1 daha okunur.
        let isSlug = !fileTitle.contains(" ") && fileTitle == fileTitle.lowercased() && fileTitle.contains("-")
        let heading = isSlug && placement.category != .core ? firstHeading(in: body) : nil
        let title = front.title?.trimmingCharacters(in: .whitespaces).nonEmpty ?? heading ?? fileTitle
        let visibility = front.visibility
        let note = Note(
            id: relativePath,
            title: title,
            category: placement.category,
            kind: front.kind,
            project: placement.project ?? front.project,
            subcluster: placement.subcluster,
            visibility: visibility,
            created: front.date ?? created,
            modified: front.modified ?? modified,
            wordCount: body.split(whereSeparator: \.isWhitespace).count,
            // Python referansıyla aynı: frontmatter dahil tüm metindeki bağlantılar.
            outgoingLinks: Wikilinks.extract(from: Substring(text)),
            excerpt: visibility == .private ? "" : excerpt(from: body),
            tags: front.tags)
        return (note, String(body))
    }

    /// Gövdenin ilk 20 satırındaki ilk "# " başlığı.
    static func firstHeading(in body: Substring) -> String? {
        for line in body.split(separator: "\n", omittingEmptySubsequences: true).prefix(20) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("# ") {
                let heading = text.dropFirst(2).trimmingCharacters(in: .whitespaces)
                return heading.isEmpty ? nil : heading
            }
        }
        return nil
    }

    /// Gövdenin başı, satır yapısıyla: boş satırlar ve "---" atılır, alıntı işareti kaldırılır,
    /// başlıklar tek "# " önekine indirilir. En çok 12 satır / 600 karakter.
    static func excerpt(from body: Substring) -> String {
        var lines: [String] = []
        var length = 0
        for raw in body.split(separator: "\n") {
            var text = raw.trimmingCharacters(in: .whitespaces)
            while text.hasPrefix(">") { text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces) }
            guard !text.isEmpty, text != "---", !text.hasPrefix("```") else { continue }
            if text.hasPrefix("#") {
                let heading = text.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                guard !heading.isEmpty else { continue }
                text = "# " + heading
            }
            lines.append(text)
            length += text.count
            if lines.count >= 12 || length >= 600 { break }
        }
        return String(lines.joined(separator: "\n").prefix(600))
    }

    /// Arama ve tek satırlık yerler için: özetin düz metin hali.
    static func plain(_ excerpt: String) -> String {
        excerpt.split(separator: "\n").map { $0.hasPrefix("# ") ? String($0.dropFirst(2)) : String($0) }.joined(separator: " ")
    }
}

/// Yüklenmiş kasa: grafik ve arama dizini.
public struct LoadedVault: Sendable {
    public let graph: VaultGraph
    public let index: SearchIndex
    public let network: NetworkLayout
    public let sphere: SphereLayout
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
