import SwiftUI

// MARK: - Easter eggs & Pursers logboek

/// De verstopte grapjes in de app. Elk egg heeft een hint (altijd leesbaar in
/// het logboek) en een onthulling (pas te lezen als je 'm gevonden hebt), zodat
/// het logboek richting geeft zonder de verrassing weg te geven.
enum EasterEgg: String, CaseIterable, Identifiable {
    case shakeBoard
    case barcodeStamp
    case taxiingPlane
    case boardFarewell
    case gateAnnouncement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shakeBoard:      return "Het bord kent je naam"
        case .barcodeStamp:    return "Pims inspectiestempel"
        case .taxiingPlane:    return "Taxiënd vliegtuigje"
        case .boardFarewell:   return "Goede reis"
        case .gateAnnouncement: return "De omroep"
        }
    }

    /// Cryptisch genoeg om leuk te blijven, concreet genoeg om te vinden.
    var hint: String {
        switch self {
        case .shakeBoard:      return "Een klapperbord houdt niet van stilstand. Beweeg eens flink."
        case .barcodeStamp:    return "Op je profiel staat een streepjescode. Pim controleert graag — blijf even doortikken."
        case .taxiingPlane:    return "Op je reispas staat een vliegtuigje dat wil taxiën. Tik het wakker."
        case .boardFarewell:   return "Houd het vertrekbord eens wat langer vast dan nodig."
        case .gateAnnouncement: return "Een halte die je al gehad hebt, wil nog één keer omgeroepen worden. Blijf tikken."
        }
    }

    var reveal: String {
        switch self {
        case .shakeBoard:      return "Schud je iPhone terwijl een klapperbord in beeld staat — het bord groet je bij naam."
        case .barcodeStamp:    return "Tik 5× snel op de streepjescode op je profiel voor Pims inspectiestempel."
        case .taxiingPlane:    return "Tik 3× op het vliegtuigje op je reispas op Start; het taxiet over de kaart."
        case .boardFarewell:   return "Houd het vertrekbord op Start ingedrukt voor een afscheidsgroet."
        case .gateAnnouncement: return "Tik 3× op een afgeronde halte in je route door de terminal voor een gate-omroep."
        }
    }

    var icon: String {
        switch self {
        case .shakeBoard:      return "iphone.gen3.radiowaves.left.and.right"
        case .barcodeStamp:    return "barcode.viewfinder"
        case .taxiingPlane:    return "airplane"
        case .boardFarewell:   return "hand.wave.fill"
        case .gateAnnouncement: return "speaker.wave.2.fill"
        }
    }
}

/// Houdt bij welke easter eggs de gebruiker heeft gevonden. Puur lokaal —
/// geen account, geen netwerk, geen Game Center.
@MainActor
final class EasterEggStore: ObservableObject {
    static let shared = EasterEggStore()
    private let key = "vt_found_easter_eggs"
    @Published private(set) var found: Set<String>

    private init() {
        found = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func discover(_ egg: EasterEgg) {
        guard !found.contains(egg.rawValue) else { return }
        found.insert(egg.rawValue)
        UserDefaults.standard.set(Array(found), forKey: key)
    }

    func hasFound(_ egg: EasterEgg) -> Bool { found.contains(egg.rawValue) }
    var foundCount: Int { EasterEgg.allCases.filter { hasFound($0) }.count }
}

/// Pursers logboek: de leesbare hintlijst. Gevonden eggs staan er compleet in,
/// nog niet gevonden eggs alleen als hint — zo weet je waar je moet zoeken
/// zonder dat de grap verklapt is.
struct PurserLogbookView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = EasterEggStore.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(EasterEgg.allCases) { egg in
                        row(egg)
                    }

                    Text("Purser Pim verstopt af en toe iets nieuws. Kom nog eens terug.")
                        .font(.frutiger(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pursers logboek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluit") { dismiss() }
                }
            }
        }
    }


    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VERBORGEN AAN BOORD")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .kerning(1.2)
            Text("\(store.foundCount) van \(EasterEgg.allCases.count) gevonden")
                .font(.frutiger(size: 22, weight: .bold))
                .foregroundStyle(.white)
            ProgressView(value: Double(store.foundCount), total: Double(EasterEgg.allCases.count))
                .tint(Theme.yellow)
            Text("Hieronder staat per grapje een hint. Vind je hem, dan schrijft Pim de hele truc erbij.")
                .font(.frutiger(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.inkGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func row(_ egg: EasterEgg) -> some View {
        let found = store.hasFound(egg)
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(found ? Theme.yellow : Theme.textSecondary.opacity(0.14))
                Image(systemName: found ? egg.icon : "questionmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(found ? Theme.ink : Theme.textSecondary)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(found ? egg.title : "Nog niet gevonden")
                    .font(.frutiger(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(found ? egg.reveal : egg.hint)
                    .font(.frutiger(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if found {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.green)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Volgende beste actie (retentie)

/// Eén logische volgende stap voor geactiveerde gebruikers die geen
/// aankomende reis/vlucht hebben (anders toont Home de NextTripCard). Beweegt
/// mee met de fase: geen tas → tas toevoegen; reis voorbij → op 'bezocht'
/// zetten; niets gepland → nieuwe reis plannen.
struct NextBestActionCard: View {
    @ObservedObject private var journey = JourneyManager.shared
    @ObservedObject private var bags = BagCollectionStore.shared
    @ObservedObject private var trips = TripsStore.shared

    let onAddBag: () -> Void
    let onPlanTrip: () -> Void
    let onOpenBucketList: () -> Void
    let onCheckBag: () -> Void

    private struct Action {
        let title: String
        let subtitle: String
        let icon: String
        let run: () -> Void
    }

    /// Een afgelopen reis waarvan het land nog niet op 'bezocht' staat.
    private var pastTripToMark: (trip: Trip, country: Country)? {
        for trip in trips.trips where trip.isPast {
            if let country = matchCountry(in: trip.destination ?? ""),
               BucketListStore.shared.status(for: country) != .visited {
                return (trip, country)
            }
        }
        return nil
    }

    private var action: Action {
        if !journey.hasBag {
            return Action(title: "Voeg je tas toe", subtitle: "Bewaar je maten en check ze bij elke maatschappij.",
                          icon: "suitcase.rolling.fill", run: onAddBag)
        }
        if let (_, country) = pastTripToMark {
            return Action(title: "Was je in \(country.name)?", subtitle: "Zet het land op 'bezocht' in je reispaspoort.",
                          icon: "flag.checkered", run: onOpenBucketList)
        }
        if !journey.hasTrip {
            return Action(title: "Plan je volgende reis", subtitle: "Krijg direct een paklijst op maat en een aftelling.",
                          icon: "map.fill", run: onPlanTrip)
        }
        return Action(title: "Check je tas nog eens", subtitle: "Regels veranderen — controleer of alles nog past.",
                      icon: "checkmark.shield.fill", run: onCheckBag)
    }

    var body: some View {
        let a = action
        Button(action: a.run) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.navy.opacity(0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: a.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.navy)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.title)
                        .font(.frutiger(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(a.subtitle)
                        .font(.frutiger(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Aha-moment: eerste geslaagde check

/// Eenmalige viering ná de allereerste geslaagde tas-check — het moment
/// waarop de kernwaarde geleverd is. Verankert dat moment én zet het
/// (bewezen) moment van blijdschap in voor delen (referral) en de volgende
/// stap.
struct FirstCheckCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    let onPlanTrip: () -> Void

    @State private var burst = false

    var body: some View {
        ZStack {
            Theme.inkGradient.ignoresSafeArea()

            // Lichtgewicht "confetti": een paar emoji die vanuit het midden
            // uitspatten — geen zware particle-engine nodig voor dit moment.
            ForEach(0..<10, id: \.self) { i in
                Text(["✈️", "🎉", "⭐️", "🧳", "✨"][i % 5])
                    .font(.system(size: 26))
                    .offset(
                        x: burst ? CGFloat.random(in: -150...150) : 0,
                        y: burst ? CGFloat.random(in: -260...(-40)) : 0
                    )
                    .opacity(burst ? 0 : 1)
                    .animation(.easeOut(duration: 1.1).delay(Double(i) * 0.03), value: burst)
            }

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                    .scaleEffect(burst ? 1 : 0.4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5), value: burst)

                VStack(spacing: 8) {
                    Text("Je tas past! 🎉")
                        .font(.frutiger(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Dit is waar Vliegtuigtas voor gemaakt is — geen verrassingen meer bij de gate.")
                        .font(.frutiger(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    // Referral op het moment van blijdschap.
                    InviteByContactCard()

                    Button {
                        dismiss()
                        onPlanTrip()
                    } label: {
                        Text("Plan meteen je reis")
                            .font(.frutiger(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .foregroundStyle(Theme.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button("Later") { dismiss() }
                        .font(.frutiger(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(16)
            }
        }
        .onAppear { burst = true }
    }
}
