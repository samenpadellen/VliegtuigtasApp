import SwiftUI

// MARK: - Bagagelabel-bouwstenen
//
// Visuele elementen om schermen eruit te laten zien als een geprint
// luchthaven-bagagelabel: crèmekleurig thermisch papier, dot-matrix
// (monospace) druk, een streepjescode, perforaties en een ophangoog.

enum TagPalette {
    /// Warm, licht "thermisch papier" — bewust altijd licht (een label is een
    /// fysiek wit kaartje), ook in dark mode.
    static let paper = Color(red: 0.98, green: 0.97, blue: 0.93)
    static let paperEdge = Color(red: 0.90, green: 0.88, blue: 0.83)
    /// Bijna-zwarte inkt, iets zachter dan puur zwart voor een gedrukte look.
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let inkSoft = Color(red: 0.44, green: 0.43, blue: 0.42)
    /// Signaal-oranje van een PRIORITY-strook.
    static let priority = Color(red: 0.95, green: 0.44, blue: 0.12)
}

/// Deterministische generator (xorshift64) uit een tekst-seed — zodat dezelfde
/// gebruiker altijd hetzelfde "labelnummer" en dezelfde streepjescode krijgt.
struct SeededGen {
    private var state: UInt64
    init(_ seed: String) {
        var h: UInt64 = 1_469_598_103_934_665_603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
        state = h == 0 ? 0xDEAD_BEEF_CAFE_F00D : h
    }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}

/// Streepjescode: verticale balken met wisselende breedte, deterministisch uit
/// de seed. Puur decoratief (geen scanbare code) maar overtuigend.
struct Barcode: View {
    let seed: String
    var height: CGFloat = 40
    var barCount: Int = 48

    private var widths: [CGFloat] {
        var g = SeededGen(seed)
        return (0..<barCount).map { _ in CGFloat(g.int(1...3)) }
    }

    var body: some View {
        GeometryReader { geo in
            let ws = widths
            let total = ws.reduce(0, +)
            HStack(spacing: 0) {
                ForEach(ws.indices, id: \.self) { i in
                    Rectangle()
                        .fill(i.isMultiple(of: 2) ? TagPalette.ink : Color.clear)
                        .frame(width: geo.size.width * ws[i] / total)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Verticale, gestippelde perforatie — de "scheurlijn" van een label.
struct TagPerforation: View {
    var body: some View {
        Rectangle()
            .fill(TagPalette.paperEdge)
            .frame(width: 1)
            .overlay(
                VLine().stroke(style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                    .foregroundStyle(TagPalette.inkSoft.opacity(0.55))
            )
    }
}

struct VLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

/// Horizontale gestippelde scheurlijn — adaptief (voor buiten het papier).
struct DashedRule: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: 0, y: g.size.height / 2))
                p.addLine(to: CGPoint(x: g.size.width, y: g.size.height / 2))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(Theme.textSecondary.opacity(0.4))
        }
    }
}

// MARK: - Gedrukte tekst (dot-matrix / monospace)

extension View {
    /// Monospace "gedrukte" tekst in labelinkt — de dot-matrix-look van een
    /// bagagelabel (bewust niet Frutiger; dit is thermisch geprint).
    func printed(_ size: CGFloat, weight: Font.Weight = .regular, soft: Bool = false) -> some View {
        self
            .font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundStyle(soft ? TagPalette.inkSoft : TagPalette.ink)
    }
}

/// Klein gedrukt veld met een kop erboven ("NAME", "SEQ", …), zoals de vakjes
/// op een echt label.
struct TagField: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .printed(8, weight: .semibold, soft: true)
                .kerning(1)
            Text(value)
                .printed(13, weight: .bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center))
    }
}

// MARK: - Papieren label-omhulsel

/// Geeft content het uiterlijk van een stuk labelpapier: crème vlak, dunne
/// rand, lichte schaduw en (optioneel) een gekartelde onderrand.
struct TagPaper<Content: View>: View {
    var corner: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(TagPalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(TagPalette.paperEdge, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
    }
}
