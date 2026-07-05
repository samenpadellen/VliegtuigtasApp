import SwiftUI
import Combine
import UIKit
import AVFoundation
import CoreHaptics

// MARK: - Solari-haptics

/// Zacht mechanisch getril op exact het flap-tempo (42 ms), synchroon met
/// het geluid en de animatie. CoreHaptics-patroon in een loop; op hardware
/// zonder haptics (iPad, Mac) automatisch een no-op.
private final class SolariHaptics {
    static let shared = SolariHaptics()

    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var activeBoards = 0

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            try? self?.engine?.start()
        }

        // Eén seconde aan zachte tikjes op het klapper-tempo, naadloos geloopt.
        var events: [CHHapticEvent] = []
        var time = 0.0
        while time < 1.0 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.30),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
                ],
                relativeTime: time
            ))
            time += 0.042
        }
        if let engine, let pattern = try? CHHapticPattern(events: events, parameters: []) {
            player = try? engine.makeAdvancedPlayer(with: pattern)
            player?.loopEnabled = true
        }
    }

    func flapsStarted() {
        activeBoards += 1
        guard activeBoards == 1, let engine, let player else { return }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    func flapsEnded() {
        activeBoards = max(0, activeBoards - 1)
        if activeBoards == 0 {
            try? player?.stop(atTime: CHHapticTimeImmediate)
        }
    }
}

// MARK: - Solari-geluid

/// Het karakteristieke geratel van een klapperbord, gesynchroniseerd met de
/// animatie. Ambient-categorie (gezet bij app-start) respecteert de
/// mute-schakelaar. Refcount omdat meerdere borden tegelijk kunnen draaien
/// (Home + shop na een schud-easteregg) en er maar één loop hoeft te spelen.
private final class SolariSound {
    static let shared = SolariSound()

    private var player: AVAudioPlayer?
    private var activeBoards = 0

    private init() {
        if let url = Bundle.main.url(forResource: "solari_flap", withExtension: "wav") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0.32
            player?.prepareToPlay()
        }
    }

    func flapsStarted() {
        activeBoards += 1
        guard activeBoards == 1, let player else { return }
        player.currentTime = 0
        player.play()
    }

    func flapsEnded() {
        activeBoards = max(0, activeBoards - 1)
        if activeBoards == 0 {
            player?.stop()
        }
    }
}

// MARK: - Schud-detectie (easteregg)

extension Notification.Name {
    static let vtDeviceShake = Notification.Name("vt_device_shake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .vtDeviceShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

// MARK: - Split-flap bord

/// Solari-/split-flap-tekst zoals op vertrekborden van vliegvelden: elke
/// positie klappert door de tekenset tot de doeltekst staat, in een golf
/// van links naar rechts. Ondersteunt meerdere regels via "\n".
///
/// Interactie:
/// - klappert elke ~34 s even opnieuw rond (levend bord, zoals op Schiphol);
/// - schud je iPhone en het bord begroet je bij naam als easteregg.
/// Alles draait op één klok: één state-write per tick.
struct SplitFlapText: View {
    let text: String
    var size: CGFloat = 22

    private static let charset = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789?!.-·")

    @State private var display: [[Character]]
    @State private var started = false
    @State private var isAnimating = false
    @State private var showingEgg = false
    @Environment(\.scenePhase) private var scenePhase

    private let lines: [[Character]]
    private let reflipTimer = Timer.publish(every: 34, on: .main, in: .common).autoconnect()

    init(_ text: String, size: CGFloat = 22) {
        self.text = text
        self.size = size
        let lines = text.uppercased().split(separator: "\n", omittingEmptySubsequences: false).map(Array.init)
        self.lines = lines
        _display = State(initialValue: lines.map { Array(repeating: " ", count: $0.count) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.24) {
            ForEach(display.indices, id: \.self) { row in
                HStack(spacing: size * 0.14) {
                    ForEach(Array(display[row].enumerated()), id: \.offset) { _, char in
                        FlapCell(char: char, size: size)
                    }
                }
            }
        }
        .task {
            guard !started else { return }
            started = true
            await animate(to: lines)
        }
        // Levend bord: af en toe opnieuw rondklapperen naar dezelfde tekst.
        .onReceive(reflipTimer) { _ in
            guard scenePhase == .active, !isAnimating, !showingEgg else { return }
            Task { await animate(to: lines) }
        }
        // Easteregg: schudden → persoonlijke groet, daarna terug.
        .onReceive(NotificationCenter.default.publisher(for: .vtDeviceShake)) { _ in
            Task { await runEasterEgg() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text.replacingOccurrences(of: "\n", with: " ")))
    }

    // MARK: - Easteregg

    private var easterEggLines: [String] {
        let name = UserSession.shared.firstName
            .uppercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        if lines.count >= 2 {
            return [name.isEmpty ? "HOI REIZIGER" : "HEY \(name)!", "GOEDE REIS"]
        }
        return [name.isEmpty ? "GOEDE REIS!" : "HEY \(name)!"]
    }

    private func runEasterEgg() async {
        guard !isAnimating, !showingEgg else { return }
        showingEgg = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        await animate(to: fit(easterEggLines), sound: true)
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        await animate(to: lines, sound: true)
        showingEgg = false
    }

    /// Past teksten in het bestaande raster: per regel gecentreerd,
    /// afgekapt of aangevuld met spaties zodat het aantal klepjes klopt.
    private func fit(_ strings: [String]) -> [[Character]] {
        lines.enumerated().map { index, line in
            let width = line.count
            guard index < strings.count else {
                return Array(repeating: " " as Character, count: width)
            }
            var chars = Array(strings[index].prefix(width))
            let padding = width - chars.count
            let leading = padding / 2
            chars = Array(repeating: " ", count: leading) + chars
                + Array(repeating: " ", count: padding - leading)
            return chars
        }
    }

    // MARK: - Animatie

    /// Klappert vanaf de húidige stand door de tekenset naar het doel —
    /// een re-flap draait dus zichtbaar rond in plaats van te resetten.
    private func animate(to targets: [[Character]], sound: Bool = false) async {
        guard !isAnimating else { return }
        isAnimating = true
        // Geluid alleen op verzoek (easteregg): bij de app-start en de
        // periodieke re-flap zou het ongevraagd opvallen. Haptics blijven —
        // die zijn subtiel en voelbaar in plaats van hoorbaar.
        if sound { SolariSound.shared.flapsStarted() }
        SolariHaptics.shared.flapsStarted()
        defer {
            isAnimating = false
            if sound { SolariSound.shared.flapsEnded() }
            SolariHaptics.shared.flapsEnded()
        }

        let targetIndex = targets.map { line in
            line.map { Self.charset.firstIndex(of: $0) ?? 0 }
        }
        var current = display.map { line in
            line.map { Self.charset.firstIndex(of: $0) ?? 0 }
        }

        var tick = 0
        let longest = lines.map(\.count).max() ?? 0
        let maxTicks = Self.charset.count + longest + 8   // veiligheidsgrens
        while tick < maxTicks {
            var busy = false
            for row in current.indices {
                for i in current[row].indices {
                    // Elke cel start één tick later dan zijn linkerbuur (golf).
                    guard tick >= i else { busy = true; continue }
                    if current[row][i] != targetIndex[row][i] {
                        current[row][i] = (current[row][i] + 1) % Self.charset.count
                        busy = true
                    }
                }
            }
            // Eén write voor het hele bord per tick.
            display = current.map { $0.map { Self.charset[$0] } }
            guard busy else { break }
            tick += 1
            try? await Task.sleep(nanoseconds: 42_000_000)
        }
        display = targets
    }
}

/// Eén klepje van het bord: donker vakje, harde monospaced letter en de
/// karakteristieke horizontale naad in het midden.
private struct FlapCell: View, Equatable {
    let char: Character
    let size: CGFloat

    var body: some View {
        Text(String(char))
            .font(.system(size: size, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.8)
            .frame(width: size * 0.78, height: size * 1.35)
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
                    .strokeBorder(.white.opacity(0.07), lineWidth: 1)
            )
    }
}

#Preview {
    SplitFlapText("PAST JOUW TAS\nIN HET VLIEGTUIG?")
        .padding()
        .background(Color(red: 0.00, green: 0.12, blue: 0.38))
}
