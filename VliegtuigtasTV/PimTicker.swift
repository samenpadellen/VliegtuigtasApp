import SwiftUI

/// Purser Pim's plek op het vertrekbord: een doorlopend "laatste nieuws"-
/// lint onderin, zoals op een echt vertrekbord/nieuwszender — geen paneel om
/// te openen, geen knop om in te drukken, gewoon aanwezig en levend. De tekst
/// mengt een paar algemene pak-tips met, als er een reis/vlucht bekend is,
/// een paar regels die daar specifiek op inspelen.
struct PimTickerView: View {
    let trip: TVTrip?
    let flight: TVFlight?

    /// Vaste, algemene tips — kleine, bewust losse kopie van de tips in de
    /// telefoon-widget: dit scherm deelt geen bestanden met de hoofdapp-
    /// target (zelfde reden als TVSavedData), en het zijn maar een handvol
    /// simpele regels, dus dupliceren is hier goedkoper dan ontkoppelen.
    private static let staticTips = [
        "Rol kleding op in plaats van vouwen — dat scheelt al snel 30% ruimte in je handbagage.",
        "Vloeistoffen boven 100 ml horen in de ruimbagage, niet in je handbagage.",
        "Powerbanks moeten juist wél in je handbagage, nooit in de ruimbagage.",
        "Weeg je tas thuis even op de badkamerweegschaal — geen verrassingen bij de balie.",
        "Check de bagageregels van je maatschappij vóór je een nieuwe koffer koopt: de maten verschillen enorm."
    ]

    private var personalizedLines: [String] {
        var lines: [String] = []
        if let trip {
            let dest = (trip.destination?.isEmpty == false ? trip.destination! : trip.name)
            switch trip.daysUntilStart {
            case ..<0: break
            case 0:    lines.append("Vandaag vertrek je naar \(dest) — goede reis!")
            case 1:    lines.append("Morgen vertrek je naar \(dest) — tijd voor de laatste check.")
            default:   lines.append("Nog \(trip.daysUntilStart) dagen tot \(dest) — check je paklijst in Vliegtuigtas.")
            }
        }
        if let flight {
            lines.append("Vlucht \(flight.number.uppercased()) staat bewaard in Vliegtuigtas — de aftelling loopt mee op je iPhone.")
        }
        return lines
    }

    private var tickerText: String {
        let all = personalizedLines + Self.staticTips
        return all.joined(separator: "     ✦     ") + "     ✦     "
    }

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                PimCapBadge()
                Text("PURSER PIM")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .kerning(1)
                    .foregroundStyle(TVTheme.ink)
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity)
            .background(TVTheme.yellow)

            GeometryReader { geo in
                Text(tickerText)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .background(WidthReader(width: $textWidth))
                    .offset(x: offset)
                    .onAppear { startScrolling(viewportWidth: geo.size.width) }
            }
            .clipped()
        }
        .frame(height: 56)
        .background(TVTheme.ink)
    }

    private func startScrolling(viewportWidth: CGFloat) {
        offset = viewportWidth
        // Snelheid vast in punten/seconde i.p.v. vaste duur: zo blijft het
        // tempo gelijk ongeacht hoeveel tips er die dag zijn.
        let pointsPerSecond: CGFloat = 90
        func loop() {
            let distance = viewportWidth + max(textWidth, viewportWidth)
            withAnimation(.linear(duration: distance / pointsPerSecond)) {
                offset = -max(textWidth, viewportWidth)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            loop()
            Timer.scheduledTimer(withTimeInterval: (viewportWidth + max(textWidth, viewportWidth)) / pointsPerSecond, repeats: true) { _ in
                offset = viewportWidth
                loop()
            }
        }
    }
}

/// Meet de breedte van de tekst zodat de lus precies aansluit i.p.v. op een
/// geschatte vaste afstand te draaien.
private struct WidthReader: View {
    @Binding var width: CGFloat
    var body: some View {
        GeometryReader { geo in
            Color.clear.onAppear { width = geo.size.width }
        }
    }
}

/// Kleine, vlakke versie van Pim's petje voor de tickerbadge — geen aparte
/// import nodig, dezelfde vormentaal als in de telefoon-app en -widget.
private struct PimCapBadge: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.08, green: 0.10, blue: 0.16))
                .frame(width: 22, height: 9)
                .offset(y: 6)
            Ellipse()
                .fill(.white)
                .frame(width: 28, height: 16)
                .offset(y: -3)
            Capsule()
                .fill(TVTheme.ink)
                .frame(width: 26, height: 8)
                .offset(y: 3)
        }
        .frame(width: 28, height: 24)
        .accessibilityHidden(true)
    }
}
