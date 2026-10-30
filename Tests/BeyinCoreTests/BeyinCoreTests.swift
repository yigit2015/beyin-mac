import Foundation
import Testing
@testable import BeyinCore

@Suite("Frontmatter")
struct FrontmatterTests {
    @Test func jsonFrontmatter() {
        let (front, body) = Frontmatter.split("---\n{\"kind\": \"Fact\", \"visibility\": \"private\", \"tags\": [\"a\"]}\n---\n# Başlık\n")
        #expect(front.kind == "fact")
        #expect(front.visibility == .private)
        #expect(front.tags == ["a"])
        #expect(body == "# Başlık\n")
    }

    @Test func yamlFrontmatter() {
        let text = "---\ntitle: \"B notu\"\ntags: [eski, kasa]\naliases:\n  - bir\nkaynak: 'C:\\x'\n---\nGövde"
        let (front, body) = Frontmatter.split(text)
        #expect(front.title == "B notu")
        #expect(front.tags == ["eski", "kasa"])
        #expect(front.fields["kaynak"] == "C:\\x")
        #expect(body == "Gövde")
    }

    @Test func dates() {
        #expect(Frontmatter.split("---\ntarih: 2026-10-06T01:21:14\n---\n").0.date != nil)
        #expect(Frontmatter.split("---\n{\"date\": \"2026-10-26T18:40:00Z\"}\n---\n").0.date != nil)
        #expect(Frontmatter.split("---\ntarih: dün\n---\n").0.date == nil)
    }

    @Test func slugTitlesUseFirstHeading() throws {
        let (note, _) = try #require(VaultLoader.makeNote(text: "# Haftalık özet: ekim\n\nmetin",
                                                          relativePath: "knowledge/haftalik-ozet.md", modified: .now, created: nil))
        #expect(note.title == "Haftalık özet: ekim")
        let (core, _) = try #require(VaultLoader.makeNote(text: "# Düşünme ortağı", relativePath: "🔮 850-Companion/last-session.md",
                                                          modified: .now, created: nil))
        #expect(core.title == "last-session")
    }

    /// docs/v3/MARKDOWN.md'deki düz YAML: satır sonu yorum, tırnaklı liste öğeleri, yer tutucu.
    @Test func upstreamYAMLSubset() {
        let text = """
        ---
        # kind: person
        kaynak: olcum   # not
        baslik: "a # b"  # yorum
        tags: [a, "b, c", 'd''e']
        aliases:
          - "x"
        ---
        """
        let front = Frontmatter.split(text + "\n").0
        #expect(front.kind == nil)
        #expect(front.fields["kaynak"] == "olcum")
        #expect(front.fields["baslik"] == "a # b")
        #expect(front.tags == ["a", "b, c", "d'e"])
        #expect(Frontmatter.split("---\ntags: [\"a\", 1]\n---\n").0.tags == ["a"])
        #expect(Frontmatter.split("---\ncreated: {{TODAY}}\n---\n").0.isTemplate)
    }

    @Test func visibilityFailsClosed() {
        #expect(Frontmatter.split("---\nvisibility: public\n---\n").0.visibility == .internal)
        #expect(Frontmatter.split("---\nvisibility: Internal\n---\n").0.visibility == .internal)
        #expect(Frontmatter.split("---\nvisibility:\n---\n").0.visibility == .internal)
        #expect(Frontmatter.split("---\nvisibility: ekip\n---\n").0.visibility == .private)
    }

    @Test func generatedSourcesAreNotNotes() {
        #expect(VaultLoader.makeNote(text: "---\n{\"generated\": true}\n---\n", relativePath: "x.md", modified: .now, created: nil) == nil)
        #expect(VaultLoader.makeNote(text: "---\ngenerated: true\n---\n", relativePath: "x.md", modified: .now, created: nil) == nil)
        #expect(VaultLoader.makeNote(text: "---\nkind: receipt\n---\n", relativePath: "x.md", modified: .now, created: nil) == nil)
        #expect(VaultLoader.makeNote(text: "---\n{\"generated\": 1}\n---\n", relativePath: "x.md", modified: .now, created: nil) != nil)
    }

    @Test func modifiedFromCommonObsidianKeys() throws {
        let (note, _) = try #require(VaultLoader.makeNote(text: "---\nmodified: 2026-10-01\n---\n", relativePath: "x.md",
                                                          modified: .now, created: nil))
        #expect(Calendar.current.dateComponents([.year, .month, .day], from: note.modified) == DateComponents(year: 2026, month: 10, day: 1))
    }

    @Test func noFrontmatterOrUnclosed() {
        #expect(Frontmatter.split("# Sadece metin").0 == Frontmatter())
        let (front, body) = Frontmatter.split("---\nkapanmayan: blok\nmetin")
        #expect(front == Frontmatter())
        #expect(body.hasPrefix("---"))
    }

    @Test func horizontalRuleIsNotFrontmatter() {
        let (front, body) = Frontmatter.split("---text\n---\n")
        #expect(front == Frontmatter())
        #expect(body == "---text\n---\n")
    }
}

@Suite("Wikilinks")
struct WikilinkTests {
    @Test func extractsTargets() {
        let links = Wikilinks.extract(from: "a [[Core]] b [[b|B notu]] [[Core#bölüm]] ![[resim.png]] [[x^blok]] [[]] [[a\nb]]")
        #expect(links == ["Core", "b", "Core", "resim.png", "x"])
    }

    @Test func keyIgnoresFolderExtensionAndCase() {
        #expect(Wikilinks.key(for: "Konular/Kılavuz.md") == Wikilinks.key(for: "kılavuz"))
    }

    /// macOS dosya adını NFD verebilir; elle yazılan bağlantı NFC'dir.
    @Test func keyIsUnicodeNFC() {
        let nfd = "knowledge/S\u{0327}iir.md"
        #expect(Wikilinks.key(for: nfd) == Wikilinks.key(for: "Şiir"))
        let graph = GraphBuilder.build(notes: [
            Note(id: nfd, title: "Şiir", category: .fact, modified: .now),
            Note(id: "a.md", title: "a", category: .fact, modified: .now, outgoingLinks: ["şiir"]),
        ])
        #expect(graph.stats.linkCount == 1)
        #expect(graph.stats.unresolvedLinkCount == 0)
    }
}

@Suite("Categorizer")
struct CategorizerTests {
    @Test(arguments: [
        ("🔮 850-Companion/Core.md", nil as String?, NoteCategory.core, nil as String?, nil as String?),
        ("knowledge/x.md", "fact", .fact, nil, nil),
        ("notes/kisiler/ayse.md", "person", .person, nil, nil),
        ("tasks/is.md", nil, .task, nil, nil),
        ("daily/2026-10-27.md", nil, .daily, nil, nil),
        ("projects/sohbet-arsivi/2026-10/s.md", "note", .chat, "sohbet-arsivi", "2026-10"),
        ("projects/eski-notlar/vaultlar/beyin/x.md", nil, .project, "eski-notlar", "vaultlar"),
        ("projects/eski-notlar/MANIFEST.md", nil, .project, "eski-notlar", nil),
        ("Hoş geldiniz.md", nil, .fact, nil, nil),
        // Resmi şablonun proje klasörü ve frontmatter önceliği
        ("🏰 300-Projects/demo/alt/x.md", nil, .project, "demo", "alt"),
        ("projects/demo/gorev.md", "task", .task, "demo", nil),
        ("daily", nil, .fact, nil, nil),
    ])
    func places(path: String, kind: String?, category: NoteCategory, project: String?, sub: String?) {
        let placement = Categorizer.place(relativePath: path, kind: kind)
        #expect(placement == Categorizer.Placement(category: category, project: project, subcluster: sub))
    }

    /// avenoxbeyin olmayan kasada üst klasör küme olur; kök notlar ve günlükler yerinde kalır.
    @Test(arguments: [
        ("Okuma/Kitaplar/Sapiens.md", nil as String?, NoteCategory.project, "Okuma" as String?, "Kitaplar" as String?),
        ("İş/toplanti.md", nil, .project, "İş", nil),
        ("Hoş geldiniz.md", nil, .fact, nil, nil),
        ("daily/2026-10-27.md", nil, .daily, nil, nil),
        ("Kişiler/ali.md", "person", .person, nil, nil),
    ])
    func placesGenericVault(path: String, kind: String?, category: NoteCategory, project: String?, sub: String?) {
        let placement = Categorizer.place(relativePath: path, kind: kind, context: .generic)
        #expect(placement == Categorizer.Placement(category: category, project: project, subcluster: sub))
    }

    @Test func frontmatterProjectAndDiscoveredCompanion() {
        #expect(Categorizer.place(relativePath: "notes/plan.md", kind: nil, project: "demo")
            == Categorizer.Placement(category: .project, project: "demo"))
        // Açık tür önce gelir: proje alanı taşıyan bilgi notu bilgi olarak kalır.
        #expect(Categorizer.place(relativePath: "knowledge/x.md", kind: "fact", project: "demo")
            == Categorizer.Placement(category: .fact, project: "demo"))
        let custom = VaultContext(layout: .avenox, companion: "🌙 Ayna")
        #expect(Categorizer.place(relativePath: "🌙 Ayna/Core.md", kind: nil, context: custom).category == .core)
        #expect(Categorizer.place(relativePath: "🔮 850-Companion/Core.md", kind: nil, context: custom).category == .fact)
    }
}

@Suite("Kasa yükleme")
struct VaultLoadingTests {
    let vault = Bundle.module.url(forResource: "Fixtures/vault", withExtension: nil)!

    @Test func skipsHiddenSensitiveAndAgentFiles() {
        let paths = VaultLoader.markdownFiles(in: vault).map(\.relativePath)
        #expect(!paths.contains { $0.hasPrefix(".obsidian") || $0.hasPrefix("receipts") || $0.hasPrefix("🔐") })
        #expect(!paths.contains("AGENTS.md"))
        #expect(!paths.contains("knowledge/SKILL.md"))
        // Şablon ve üretilmiş dosya taranır ama not sayılmaz (frontmatter'dan anlaşılır).
        #expect(paths.contains("📋 Templates/Kisi.md"))
    }

    @Test func buildsGraphAndStats() {
        let loaded = VaultLoader.loadSync(vaultURL: vault)
        let stats = loaded.graph.stats
        #expect(stats.noteCount == 9)
        // Core–Kurallar, a–Core, a–b (b→a ve a→b tek sayılır; [[Core]] iki kez geçse de tek)
        #expect(stats.linkCount == 3)
        #expect(stats.unresolvedLinkCount == 1)  // [[Yok]]
        #expect(stats.isolatedCount == 5)        // ayse, c, sohbet, plan, is-listesi
        #expect(stats.privateCount == 1)
        #expect(stats.count(.core) == 2)
        #expect(stats.count(.project) == 3)
        #expect(stats.count(.task) == 1)
        #expect(stats.count(.chat) == 1)
        #expect(stats.count(.daily) == 0)
        #expect(stats.bySubcluster["project:eski-notlar/vaultlar"] == 1)
        #expect(loaded.graph.note("🏰 300-Projects/demo/plan.md")?.project == "demo")
        #expect(loaded.graph.note("notes/is-listesi.md")?.project == "demo")
        // a: giden Core, b; gelen b → 3
        #expect(stats.topConnected.first == RankedNote(id: "knowledge/a.md", degree: 3))
    }

    @Test func noteDetails() throws {
        let graph = VaultLoader.loadSync(vaultURL: vault).graph
        let b = try #require(graph.note("projects/eski-notlar/vaultlar/b.md"))
        #expect(b.title == "B notu")
        #expect(b.tags == ["eski", "kasa"])
        let tarih = try #require(b.created)
        #expect(Calendar.current.dateComponents([.year, .month, .day], from: tarih) == DateComponents(year: 2026, month: 10, day: 6))
        let ayse = try #require(graph.note("notes/kisiler/ayse.md"))
        #expect(ayse.title == "Ayşe Yılmaz")
        #expect(ayse.isPrivate)
        #expect(ayse.excerpt.isEmpty)
        // Kısa dosya adı korunur (slug değil); çekirdek her zaman dosya adıyla
        #expect(graph.note("knowledge/a.md")?.title == "a")
        #expect(graph.note("🔮 850-Companion/Core.md")?.title == "Core")
        let chat = try #require(graph.notes.values.first { $0.category == .chat })
        #expect(chat.title == "Beyin kurulumu")
        #expect(graph.incoming(to: "🔮 850-Companion/Core.md") == ["knowledge/a.md"])
        #expect(Set(graph.neighbors(of: "knowledge/a.md")) == ["🔮 850-Companion/Core.md", "projects/eski-notlar/vaultlar/b.md"])
    }

    @Test func searchFindsTurkishTextAndHidesPrivate() {
        let loaded = VaultLoader.loadSync(vaultURL: vault)
        let hits = loaded.index.search("ŞİİR", in: loaded.graph, includePrivate: true, limit: 5)
        #expect(hits.map(\.id) == ["projects/eski-notlar/vaultlar/b.md"])
        #expect(loaded.index.search("gizli", in: loaded.graph, includePrivate: false, limit: 5).isEmpty)
        #expect(loaded.index.search("kasa yapısı", in: loaded.graph, includePrivate: true, limit: 5).first?.id == "knowledge/a.md")
    }
}

/// Diskte geçici kasa: keşif kuralları (companion, index.json, Obsidian şablon ayarı, sembolik bağ).
@Suite("Kasa keşfi")
struct DiscoveryTests {
    func makeVault(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "beyin-test-" + UUID().uuidString)
        for (path, text) in files {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }

    @Test func companionIsDiscovered() throws {
        let named = try makeVault(["Benim Companion/Core.md": "", "notlar/a.md": ""])
        #expect(VaultContext.companionFolder(in: named) == "Benim Companion")
        let byCore = try makeVault(["🌙 Ayna/Soul.md": "", "notlar/a.md": ""])
        #expect(VaultContext.companionFolder(in: byCore) == "🌙 Ayna")
        let two = try makeVault(["A Companion/Core.md": "", "B Echo/Core.md": ""])
        #expect(VaultContext.companionFolder(in: two) == nil)
        let archived = try makeVault(["Companion Arşiv/Core.md": ""])
        #expect(VaultContext.companionFolder(in: archived) == nil)
        #expect(VaultContext.discover(in: try makeVault(["Okuma/a.md": ""])).layout == .generic)
    }

    @Test func userExcludedDirsFromRuntimeIndex() throws {
        let state = try makeVault(["index.json": #"{"excluded_dirs": ["Arşiv-Kod"]}"#])
        let vault = try makeVault([
            ".beyin-runtime.json": #"{"state": "\#(state.path)", "schema": 1}"#,
            "projects/x/ARŞİV-KOD/README.md": "", "projects/x/not.md": "",
        ])
        #expect(VaultLoader.markdownFiles(in: vault).map(\.relativePath) == ["projects/x/not.md"])
        // Korunan bir ad listeyi geçersiz kılar: upstream de o zaman her şeyi indeksler.
        try #"{"excluded_dirs": ["Arşiv-Kod", "knowledge"]}"#.write(to: state.appending(path: "index.json"), atomically: true, encoding: .utf8)
        #expect(VaultLoader.markdownFiles(in: vault).count == 2)
    }

    @Test func obsidianTemplateFolderAndSymlinks() throws {
        let outside = try makeVault(["dis.md": ""])
        let vault = try makeVault([
            ".obsidian/templates.json": #"{"folder": "Şablonlarım/"}"#,
            "Şablonlarım/Gunluk.md": "", "notlar/a.md": "",
        ])
        try FileManager.default.createSymbolicLink(at: vault.appending(path: "bag"), withDestinationURL: outside)
        try FileManager.default.createSymbolicLink(at: vault.appending(path: "notlar/bag.md"),
                                                   withDestinationURL: outside.appending(path: "dis.md"))
        #expect(VaultLoader.markdownFiles(in: vault).map(\.relativePath) == ["notlar/a.md"])
    }

    @Test(arguments: [
        ("🔐 Kasa", true), ("410-Şifreler", true), ("MU\u{0308}S\u{0327}TERI\u{0307}LER", true), ("Private Notes", true),
        ("Kasaba gezisi", false), ("Okuma", false), ("vendor", false),
    ])
    func sensitiveFolders(name: String, sensitive: Bool) {
        #expect(SourceRules.isSensitive(name) == sensitive)
    }

    @Test func dirKeyFoldsTurkishI() {
        #expect(SourceRules.dirKey("ARŞİV") == SourceRules.dirKey("arşiv"))
        #expect(SourceRules.dirKey("IŞIK") == SourceRules.dirKey("ışık"))
        #expect(SourceRules.dirKey("Node_Modules") == "node_modules")
    }
}

@Suite("Gerçek kasa", .enabled(if: ProcessInfo.processInfo.environment["BEYIN_REAL_VAULT"] != nil))
struct RealVaultTests {
    @Test func printsStats() {
        let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BEYIN_REAL_VAULT"]!)
        let start = Date()
        let stats = VaultLoader.loadSync(vaultURL: url).graph.stats
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        print("GERCEK notes=\(stats.noteCount) links=\(stats.linkCount) unresolved=\(stats.unresolvedLinkCount) isolated=\(stats.isolatedCount) private=\(stats.privateCount) ms=\(ms)")
        print("GERCEK kategoriler=\(stats.byCategory.map { "\($0.key.rawValue):\($0.value)" }.sorted())")
        print("GERCEK top=\(stats.topConnected.prefix(6).map { "\(($0.id as NSString).lastPathComponent):\($0.degree)" })")
        #expect(stats.noteCount > 0)
    }
}
