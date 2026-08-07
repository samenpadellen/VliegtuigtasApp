import SwiftUI

// Alternatieve app-iconen bestaan niet op Mac Catalyst.
#if !targetEnvironment(macCatalyst)

/// Alternatieve app-iconen, instelbaar via het profiel. `iconName` is de
/// naam zoals opgeslagen in de asset-catalogus (en dus in Info.plist),
/// doorgegeven aan `UIApplication.setAlternateIconName` — nil betekent het
/// standaardicoon (dat kan nooit expliciet als "alternate" gezet worden).
enum AppIconOption: String, CaseIterable, Identifiable {
    case standaard
    case pim
    case flap
    case vertrek
    case bagage
    case gate
    case copilot

    var id: String { rawValue }

    var iconName: String? {
        switch self {
        case .standaard: return nil
        case .pim:       return "AppIcon-Pim"
        case .flap:      return "AppIcon-Flap"
        case .vertrek:   return "AppIcon-Vertrek"
        case .bagage:    return "AppIcon-Bagage"
        case .gate:      return "AppIcon-Gate"
        case .copilot:   return "AppIcon-Copilot"
        }
    }

    /// Losse preview-imagesets (géén appiconset): appicon-assets zijn niet
    /// rechtstreeks laadbaar via Image(_:), dus voor de kiezer bewaren we
    /// een kopie van elk icoon als gewone afbeelding.
    var previewAsset: String {
        switch self {
        case .standaard: return "AppIconPreviewDefault"
        case .pim:       return "AppIconPreviewPim"
        case .flap:      return "AppIconPreviewFlap"
        case .vertrek:   return "AppIconPreviewVertrek"
        case .bagage:    return "AppIconPreviewBagage"
        case .gate:      return "AppIconPreviewGate"
        case .copilot:   return "AppIconPreviewCopilot"
        }
    }

    var title: String {
        switch self {
        case .standaard: return "Standaard"
        case .pim:       return "Purser Pim"
        case .flap:      return "Vertrekbord"
        case .vertrek:   return "Vertrek"
        case .bagage:    return "Bagagehal"
        case .gate:      return "Gate 21"
        case .copilot:   return "Copilot"
        }
    }

    var subtitle: String {
        switch self {
        case .standaard: return "Het originele Vliegtuigtas-icoon"
        case .pim:       return "De pet van je bagageassistent"
        case .flap:      return "Solari-klepjes, zoals op Home"
        case .vertrek:   return "Geel bord richting vertrek"
        case .bagage:    return "Blauw bord van de bagagehal"
        case .gate:      return "Bijna instappen"
        case .copilot:   return "Exclusief — ontgrendel door een vriend uit te nodigen"
        }
    }

    /// Alleen Copilot is vergrendeld — ontgrendelt zodra je daadwerkelijk
    /// een uitnodigings-sms hebt verstuurd (ReferralManager.hasInvited).
    @MainActor
    var isLocked: Bool {
        self == .copilot && !ReferralManager.shared.hasInvited
    }

    static var current: AppIconOption {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .standaard
    }
}

/// Kiezer voor het app-icoon: verandert direct bij het tikken, met directe
/// feedback als het (zeldzaam) niet lukt.
struct AppIconPicker: View {
    @ObservedObject private var referral = ReferralManager.shared
    @State private var selected: AppIconOption = .current
    @State private var errorMessage: String?
    @State private var showLockedMessage = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(AppIconOption.allCases) { option in
                Button {
                    if option.isLocked {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        withAnimation(.easeInOut(duration: 0.2)) { showLockedMessage = true }
                    } else {
                        select(option)
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(option.previewAsset)
                                .resizable()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                                )
                                .opacity(option.isLocked ? 0.4 : 1)

                            if option.isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(Theme.navy, in: Circle())
                                    .offset(x: 4, y: 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.frutiger(size: 15, weight: .bold))
                                .foregroundStyle(option.isLocked ? Theme.textSecondary : Theme.textPrimary)
                            Text(option.subtitle)
                                .font(.frutiger(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()

                        if !option.isLocked {
                            Image(systemName: selected == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(selected == option ? Theme.green : Theme.textSecondary.opacity(0.35))
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            if showLockedMessage {
                Label("Nodig een vriend uit (Profiel > Deel Vliegtuigtas) om Copilot te ontgrendelen.", systemImage: "gift")
                    .font(.frutiger(size: 12))
                    .foregroundStyle(Theme.navy)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.frutiger(size: 12))
                    .foregroundStyle(Theme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: referral.hasInvited) { _, unlocked in
            if unlocked {
                withAnimation { showLockedMessage = false }
            }
        }
    }

    private func select(_ option: AppIconOption) {
        guard option != selected, UIApplication.shared.supportsAlternateIcons else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            DispatchQueue.main.async {
                if let error {
                    errorMessage = "Kon het icoon niet wijzigen: \(error.localizedDescription)"
                } else {
                    errorMessage = nil
                    selected = option
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}

#endif
