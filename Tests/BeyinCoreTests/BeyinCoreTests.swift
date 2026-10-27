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

    @Test func slugTitlesUseFirstHeading() {
        let (note, _) = VaultLoader.makeNote(text: "# Haftalık özet: ekim\n\nmetin", relativePath: "knowledge/haftalik-ozet.md",
                                             modified: .now, created: nil)
        #expect(note.title == "Haftalık özet: ekim")
        let (core, _) = VaultLoader.makeNote(text: "# Düşünme ortağı", relativePath: "🔮 850-Companion/last-session.md",
                                             modified: .now, created: nil)
        #expect(core.title == "last-session")
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
        let placement = Categorizer.place(relativePath: path, kind: kind, layout: .generic)
        #expect(placement == Categorizer.Placement(category: category, project: project, subcluster: sub))
    }
}

@Suite("Kasa yükleme")
struct VaultLoadingTests {
    let vault = Bundle.module.url(forResource: "Fixtures/vault", withExtension: nil)!

    @Test func skipsHiddenTemplatesAndAgentFiles() {
        let paths = VaultLoader.markdownFiles(in: vault).map(\.relativePath)
        #expect(paths.count == 7)
        #expect(!paths.contains { $0.hasPrefix(".obsidian") || $0.hasPrefix("📋") || $0 == "AGENTS.md" })
    }

    @Test func buildsGraphAndStats() {
        let loaded = VaultLoader.loadSync(vaultURL: vault)
        let stats = loaded.graph.stats
        #expect(stats.noteCount == 7)
        // Core–Kurallar, a–Core, a–b (b→a ve a→b tek sayılır; [[Core]] iki kez geçse de tek)
        #expect(stats.linkCount == 3)
        #expect(stats.unresolvedLinkCount == 1)  // [[Yok]]
        #expect(stats.isolatedCount == 3)        // ayse, c, sohbet
        #expect(stats.privateCount == 1)
        #expect(stats.count(.core) == 2)
        #expect(stats.count(.project) == 2)
        #expect(stats.count(.chat) == 1)
        #expect(stats.count(.daily) == 0)
        #expect(stats.bySubcluster["project:eski-notlar/vaultlar"] == 1)
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
