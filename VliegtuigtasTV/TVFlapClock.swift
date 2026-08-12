import SwiftUI
import Combine

/// Eigen, minimale tvOS-kopie van de Solari-/split-flap-animatie uit
/// SplitFlapBoard.swift (hoofdapp): zelfde golfbeweging door de tekenset,
/// maar zonder UIKit/AVFoundation/CoreHaptics — geen Taptic Engine op tvOS,
/// en dit scherm is bewust een stil, alleen-kijken-bord.
struct TVSplitFlapText: View {
    var text: String
    var size: CGFloat = 20

    private static let charset = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:")

    @State private var display: [Character] = []
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: size * 0.14) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, char in
                TVFlapCell(char: char, size: size)
            }
        }
        .task { await animate(to: Array(text.uppercased())) }
        .onChange(of: text) { _, newValue in
            Task { await animate(to: Array(newValue.uppercased())) }
        }
    }

    /// Klappert vanaf de huidige stand door de tekenset naar het doel, één
    /// cel per tick verschoven (golf van links naar rechts) — net als het
    /// origineel, maar hier voor willekeurig wisselende tekst (tijd/datum)
    /// in plaats van een vaste boodschap.
    private func animate(to target: [Character]) async {
        guard !isAnimating else { return }
        isAnimating = true
        defer { isAnimating = false }

        if display.count != target.count {
            display = Array(repeating: " ", count: target.count)
        }

        let targetIndex = target.map { Self.charset.firstIndex(of: $0) ?? 0 }
        var current = display.map { Self.charset.firstIndex(of: $0) ?? 0 }

        var tick = 0
        let maxTicks = Self.charset.count + target.count + 8
        while tick < maxTicks {
            var busy = false
            for i in current.indices {
                guard tick >= i else { busy = true; continue }
                if current[i] != targetIndex[i] {
                    current[i] = (current[i] + 1) % Self.charset.count
                    busy = true
                }
            }
            display = current.map { Self.charset[$0] }
            guard busy else { break }
            tick += 1
            try? await Task.sleep(nanoseconds: 42_000_000)
        }
        display = target
    }
}

/// Eén klepje: donker vakje, harde monospaced letter, karakteristieke naad.
private struct TVFlapCell: View {
    let char: Character
    let size: CGFloat

    var body: some View {
        Text(char == " " ? "" : String(char))
            .font(.system(size: size, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: size * 0.72, height: size * 1.35)
            .background(
                RoundedRectangle(cornerRadius: size * 0.14)
                    .fill(Color(red: 0.05, green: 0.09, blue: 0.18))
            )
            .overlay(
                Rectangle()
                    .fill(.black.opacity(0.35))
                    .frame(height: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.14)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

/// De kop-klok van het bord: wisselt elke cyclus tussen tijd en datum, met
/// de klapper-animatie als overgang — precies wat een echt Solari-bord ook
/// doet als het tussen twee stukjes info wisselt. Beide teksten worden op
/// dezelfde breedte gecentreerd, zodat het bord niet breder/smaller springt
/// bij het wisselen.
struct TVFlapClock: View {
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    /// 8 s tijd, 4 s datum, afgeleid van de kloktijd zelf i.p.v. een eigen
    /// wisseltimer — zo kan dit nooit wegdriften van wat er staat.
    private var showingDate: Bool {
        Int(now.timeIntervalSinceReferenceDate) % 12 >= 8
    }

    private var display: String {
        let time = Self.timeFormatter.string(from: now)
        let date = Self.dateFormatter.string(from: now).uppercased()
        let width = max(time.count, date.count)
        return Self.centered(showingDate ? date : time, width: width)
    }

    private static func centered(_ s: String, width: Int) -> String {
        let padding = max(0, width - s.count)
        let leading = padding / 2
        return String(repeating: " ", count: leading) + s + String(repeating: " ", count: padding - leading)
    }

    var body: some View {
        TVSplitFlapText(text: display, size: 19)
            .onReceive(ticker) { now = $0 }
    }
}
