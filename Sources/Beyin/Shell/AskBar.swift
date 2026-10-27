import BeyinCore
import SwiftUI

/// "Beyne sor…" alanı (Bileşenler · 09): floating cam kapsül, 52 yükseklik, genişlik 540 (en az 320).
/// ↵ ile yerel arama; sonuçlar inceleme panelinin C haline gider. Salt okunur: hiçbir dosya yazılmaz.
struct AskBar: View {
    let store: VaultStore
    let shell: ShellState

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var scope: AskScope = .all

    var body: some View {
        HStack(spacing: 10) {
            OrbView(size: 28, pulseTrigger: shell.askPulse)

            TextField("Beyne sor…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(palette.t1)
                .focused($isFocused)
                .onSubmit(submit)
                .onKeyPress(.upArrow) { moveCursor(-1) }
                .onKeyPress(.downArrow) { moveCursor(1) }
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.command), let id = cursorHit?.id else { return .ignored }
                    store.openInObsidian(id)
                    return .handled
                }
                .accessibilityLabel("Beyne sor")

            if let ask = shell.ask {
                Chip(height: 26) {
                    Dot(color: palette.gold, size: 6, glow: palette.goldGlow)
                    Text("\(ask.hits.count) eşleşme").monospacedDigit()
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            scopeMenu

            if shell.ask != nil {
                Button(action: clear) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle(diameter: 36))
                .background(palette.chip, in: Circle())
                .accessibilityLabel("Aramayı temizle")
                .help("Aramayı temizle (Esc)")
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Palette.primaryGradient, in: Circle())
                        .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                                      startPoint: .top, endPoint: .center), lineWidth: 1))
                        .shadow(color: Color(hex: 0x8B5CF6, opacity: 0.55), radius: 9)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Sor")
                .help("Sor (↵)")
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, 8)
        .frame(height: 52)
        .frame(minWidth: 320, idealWidth: 540, maxWidth: 540)
        .floatingGlass(in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(palette.violet2.opacity(isFocused ? 0.45 : 0), lineWidth: 1)
                .shadow(color: palette.violet.opacity(isFocused ? 0.35 : 0), radius: 12)
                .allowsHitTesting(false)
        }
        .motion(Motion.snappy, value: isFocused)
        .motion(Motion.pop, value: shell.ask?.hits.count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Beyne sor")
        .onChange(of: shell.focusRequest) { _, request in
            if request.target == .ask { isFocused = true }
        }
        .onChange(of: shell.ask?.query) { _, query in
            // Temizlenince alan boşalır; başka yerden (palet, açılış) gelen soru alana yazılır.
            draft = query ?? ""
            if let ask = shell.ask { scope = ask.scope }
        }
        .onAppear {
            if let ask = shell.ask {
                draft = ask.query
                scope = ask.scope
            }
        }
    }

    private var scopeMenu: some View {
        Menu {
            Button(AskScope.all.title) { scope = .all }
            Section("Tür") {
                ForEach(NoteCategory.allCases) { category in
                    Button(category.pluralTitle) { scope = .category(category) }
                        .disabled(store.graph.stats.count(category) == 0)
                }
            }
            if !store.projects.isEmpty {
                Section("Proje") {
                    ForEach(store.projects, id: \.self) { project in
                        Button(project) { scope = .project(project) }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(scope.title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.t2)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .chipSurface()
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Kapsam")
        .accessibilityValue(scope.title)
        .onChange(of: scope) { _, newScope in
            // Sonuçlar açıkken kapsam değişirse aynı soruyu yeniden çalıştır.
            if let ask = shell.ask, ask.scope != newScope { run(ask.query, scope: newScope) }
        }
    }

    /// ↵: soru değişmediyse ve sonuçlar açıksa imleçteki notu odaklar; aksi halde yeni arama.
    private func submit() {
        if let ask = shell.ask, draft.trimmingCharacters(in: .whitespacesAndNewlines) == ask.query, let hit = cursorHit {
            withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) {
                shell.show(hit.id, in: store)
                if let note = store.graph.note(hit.id) { store.focusedCategory = note.category }
            }
            return
        }
        run(draft, scope: scope)
    }

    private var cursorHit: SearchHit? {
        let hits = shell.visibleHits(in: store)
        return hits.indices.contains(shell.askCursor) ? hits[shell.askCursor] : nil
    }

    private func moveCursor(_ delta: Int) -> KeyPress.Result {
        guard shell.ask != nil else { return .ignored }
        shell.moveAskCursor(by: delta, store: store)
        if shell.inspectorPage != .results { shell.inspectorPage = .results }
        return .handled
    }

    private func run(_ query: String, scope: AskScope) {
        withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) {
            shell.runAsk(query, scope: scope, store: store)
        }
    }

    private func clear() {
        withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.clearAsk(in: store) }
        isFocused = false
    }
}
