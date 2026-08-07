import SwiftUI

// MARK: - Bagagelabel-bouwstenen (moderne stijl)
//
// Visuele taal geïnspireerd op een luchthavenbagagelabel/instapkaart, maar
// met de kaart-esthetiek van de rest van de app: Frutiger-typografie, het
// merk-navy/sky-verloop en systeemkleuren (donker-modus-proof) i.p.v. het
// vorige "thermisch papier"-uiterlijk met dot-matrix-lettertype.

enum TagPalette {
    static let ink = Theme.textPrimary
    static let inkSoft = Theme.textSecondary
    /// Statusaccent — hetzelfde geel als de "VOLGENDE"-badge elders in de app.
    static let accent = Theme.yellow
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
/// de seed. Puur decoratief (geen scanbare code) maar overtuigend — dun en in
/// het merk-navy, i.p.v. de zware zwarte thermische-printer-look van voorheen.
struct Barcode: View {
    let seed: String
    var height: CGFloat = 32
    var barCount: Int = 42
    var tint: Color = Theme.navy

    private var widths: [CGFloat] {
        var g = SeededGen(seed)
        return (0..<barCount).map { _ in CGFloat(g.int(1...3)) }
    }

    var body: some View {
        GeometryReader { geo in
            let ws = widths
            let total = ws.reduce(0, +)
            HStack(spacing: 1.5) {
                ForEach(ws.indices, id: \.self) { i in
                    Capsule()
                        .fill(i.isMultiple(of: 2) ? tint.opacity(0.8) : Color.clear)
                        .frame(width: geo.size.width * ws[i] / total)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Rij kleine stipjes: de "perforatie" tussen twee delen van het label —
/// dezelfde beeldtaal als de scheidingslijn op de vluchtkaart (Flights.swift).
struct TagPerforation: View {
    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 7
            let count = max(Int(geo.size.width / spacing), 1)
            HStack(spacing: spacing - 3) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle().fill(TagPalette.inkSoft.opacity(0.22)).frame(width: 3, height: 3)
                }
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

/// Horizontale gestippelde scheurlijn — adaptief (voor buiten het label-kaartje).
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

// MARK: - Gedrukte tekst

extension View {
    /// "Gedrukte" labeltekst in Frutiger — bewust hetzelfde lettertype als de
    /// rest van de app (i.p.v. het vorige dot-matrix-monospace), zodat het
    /// label bij de app past. Kerning + kleine kapitalen houden de label-look.
    func printed(_ size: CGFloat, weight: Font.Weight = .regular, soft: Bool = false) -> some View {
        self
            .font(.frutiger(size: size, weight: weight))
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
                .printed(9, weight: .bold, soft: true)
                .kerning(1)
            Text(value)
                .printed(15, weight: .bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center))
    }
}

// MARK: - Label-omhulsel

/// Geeft content het uiterlijk van een moderne labelkaart: systeemachtergrond
/// (donker-modus-proof), afgeronde hoeken en een zachte schaduw i.p.v. het
/// vorige crèmekleurige "thermisch papier".
struct TagPaper<Content: View>: View {
    var corner: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}
