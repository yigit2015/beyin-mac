import BeyinCore
import SwiftUI

/// Zaman çizelgesi (Bileşenler · 10), yalnız gösterim: görünen notların değiştirilme tarihine göre haftalık histogram.
/// Floating kapsül, 38 yükseklik; histogram 16 yükseklik, sütun aralığı 2, teal gradyan %60; ray 2 pt teal → mor.
struct TimelineStrip: View {
    let store: VaultStore

    @Environment(\.palette) private var palette

    /// En çok 52 hafta gösterilir; daha eskiler ilk sütuna katılmaz, toplamda sayılır.
    private static let maxWeeks = 52

    var body: some View {
        let histogram = Histogram(notes: visibleNotes, maxWeeks: Self.maxWeeks)
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.t2)
                .frame(width: 28, height: 28)
                .background(palette.chip, in: Circle())
                .accessibilityHidden(true)

            Text(histogram.startLabel)
                .font(.system(size: 11))
                .foregroundStyle(palette.t3)

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    bars(histogram, width: proxy.size.width)
                        .padding(.bottom, 6)
                    LinearGradient(colors: [palette.teal.opacity(0.5), palette.violet2], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 2)
                        .clipShape(Capsule())
                        .padding(.bottom, 3)
                }
                .overlay(alignment: .bottomTrailing) {
                    // Tutamak bugüne kilitli: 12 altın daire + 3 pt %20 halka + 12 parıltı.
                    Circle()
                        .fill(palette.gold)
                        .frame(width: 12, height: 12)
                        .background(Circle().fill(palette.gold.opacity(0.2)).padding(-3))
                        .shadow(color: palette.goldGlow, radius: 6)
                        .offset(x: 6, y: 2)
                }
            }
            .frame(height: 24)

            Text("\(BeyinFormat.shortDate(.now)) · \(BeyinFormat.number(visibleNotes.count)) not")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(palette.t2)
                .lineLimit(1)
                .padding(.leading, 6)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .frame(height: 38)
        .floatingGlass(in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zaman çizelgesi")
        .accessibilityValue(histogram.summary)
    }

    private var visibleNotes: [Note] {
        let visible = store.visibleNoteIDs
        return store.graph.notes.values.filter { visible.contains($0.id) }
    }

    private func bars(_ histogram: Histogram, width: CGFloat) -> some View {
        let maxCount = max(1, histogram.counts.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(histogram.counts.enumerated()), id: \.offset) { _, count in
                // Karekök ölçek: bir içe aktarma sıçraması diğer haftaları ezmesin.
                let height = count == 0 ? 1 : 2 + 14 * sqrt(Double(count) / Double(maxCount))
                UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                    .fill(LinearGradient(colors: [palette.teal, palette.teal.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                    .opacity(count == 0 ? 0.25 : 0.6)
                    .frame(height: height)
            }
        }
        .frame(height: 16, alignment: .bottom)
    }
}

/// Haftalık kova sayımı.
private struct Histogram {
    let counts: [Int]
    let start: Date

    init(notes: [Note], maxWeeks: Int, now: Date = .now) {
        let calendar = Calendar(identifier: .iso8601)
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let earliest = notes.map(\.modified).min() ?? now
        let earliestWeek = calendar.dateInterval(of: .weekOfYear, for: earliest)?.start ?? earliest
        let span = (calendar.dateComponents([.weekOfYear], from: earliestWeek, to: thisWeek).weekOfYear ?? 0) + 1
        let weeks = min(maxWeeks, max(12, span))
        let start = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek) ?? thisWeek
        var counts = Array(repeating: 0, count: weeks)
        for note in notes where note.modified >= start {
            let index = calendar.dateComponents([.weekOfYear], from: start, to: note.modified).weekOfYear ?? 0
            counts[min(max(index, 0), weeks - 1)] += 1
        }
        self.counts = counts
        self.start = start
    }

    var startLabel: String { BeyinFormat.month(start) }

    var summary: String {
        let total = counts.reduce(0, +)
        return "Son \(counts.count) haftada \(total) not değişti"
    }
}
