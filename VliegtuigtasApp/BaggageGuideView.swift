import SwiftUI

// MARK: - Inhoudsmodel

private struct GuideRule: Identifiable {
    enum Status {
        case allowed, conditional, forbidden

        var color: Color {
            switch self {
            case .allowed:     return Theme.green
            case .conditional: return Theme.orange
            case .forbidden:   return Theme.red
            }
        }

        var icon: String {
            switch self {
            case .allowed:     return "checkmark.circle.fill"
            case .conditional: return "exclamationmark.circle.fill"
            case .forbidden:   return "xmark.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .allowed:     return "Mag mee"
            case .conditional: return "Let op"
            case .forbidden:   return "Mag niet"
            }
        }
    }

    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let status: Status
}

/// EU-handbagageregels (stand 2026). Statische kennis in de app: geldt voor
/// álle maatschappijen; de per-maatschappij maten staan bij de airlines zelf.
private enum GuideContent {
    static let allowed: [GuideRule] = [
        GuideRule(
            icon: "drop.fill",
            title: "Vloeistoffen en de 100 ml regel",
            text: "Verpakkingen van max. 100 ml per stuk, samen in één doorzichtig, hersluitbaar zakje van max. 1 liter (1 per persoon). Ook mascara, deodorant, haarlak en smeerbaar eten (pindakaas, brie) tellen als vloeistof. De inhoud op het etiket telt, niet hoeveel er nog in zit.",
            status: .conditional
        ),
        GuideRule(
            icon: "battery.100percent.bolt",
            title: "Powerbanks & elektronica",
            text: "Powerbanks moeten juist in je handbagage en nooit in het ruim. Tot 100 Wh (±27.000 mAh) vrij toegestaan. 100 tot 160 Wh: toestemming van de maatschappij nodig, max. 2 stuks. Boven 160 Wh: verboden op passagiersvluchten.",
            status: .conditional
        ),
        GuideRule(
            icon: "fork.knife",
            title: "Vast eten",
            text: "Belegde broodjes, koekjes en fruit mogen gewoon door de security. Smeerbaar of vloeibaar eten (yoghurt, soep) valt onder de 100 ml regel.",
            status: .allowed
        ),
        GuideRule(
            icon: "pills.fill",
            title: "Medicijnen, babyvoeding & dieetvoeding",
            text: "Mogen boven de 100 ml mee, maar meld ze apart en houd ze apart verpakt. Medicijnen in de originele verpakking met etiket; voor sterke medicatie kan een doktersverklaring of Schengenverklaring nodig zijn.",
            status: .conditional
        ),
        GuideRule(
            icon: "scissors",
            title: "Kleine scherpe voorwerpen",
            text: "Elektrisch scheerapparaat, nagelschaartje met blad korter dan 6 cm, pincet, nagelknipper, nagelvijl en wegwerpscheermesjes mogen mee.",
            status: .allowed
        ),
        GuideRule(
            icon: "waterbottle",
            title: "Lege drinkfles",
            text: "Gevuld boven 100 ml mag niet, maar leeg mag de fles gewoon mee. Bijvullen kan bij een watertappunt voorbij de security.",
            status: .allowed
        )
    ]

    static let forbidden: [GuideRule] = [
        GuideRule(
            icon: "drop.triangle.fill",
            title: "Grote vloeistoffen",
            text: "Alles boven 100 ml, behalve medicijnen, babyvoeding en dieetvoeding (apart aanmelden).",
            status: .forbidden
        ),
        GuideRule(
            icon: "scissors.badge.ellipsis",
            title: "Scherpe voorwerpen",
            text: "Scharen met een lemmet langer dan 6 cm, (zak)messen, losse scheermesjes, multitools met mes, stanleymessen, bijlen en hakmessen. Mogen wél in de ruimbagage.",
            status: .forbidden
        ),
        GuideRule(
            icon: "exclamationmark.octagon.fill",
            title: "Wapens & gevaarlijke stoffen",
            text: "Explosieven, vuurwapens, vuurwerk en chemische stoffen. Ook speelgoed dat erop lijkt, zoals een waterpistool, en berenspray.",
            status: .forbidden
        ),
        GuideRule(
            icon: "figure.fencing",
            title: "Stompe voorwerpen & slagwapens",
            text: "Knuppels en stokken, zoals gummiknuppels en wapenstokken.",
            status: .forbidden
        ),
        GuideRule(
            icon: "bolt.fill",
            title: "Stroomstootwapens en tasers",
            text: "Stroomstootwapens, tasers, elektroschokwapens en prikstokken voor vee.",
            status: .forbidden
        ),
        GuideRule(
            icon: "flame.fill",
            title: "Aanstekers & lucifers",
            text: "Eén kleine aansteker of doosje veiligheidslucifers mag alleen óp je lichaam (broekzak), niet los in je tas of handbagage.",
            status: .forbidden
        ),
        GuideRule(
            icon: "scooter",
            title: "Hoverboards e.d.",
            text: "Zelfbalancerende apparaten op lithiumbatterij zijn verboden, ook met losgekoppelde of verwijderde accu.",
            status: .forbidden
        )
    ]
}

// MARK: - Gids-scherm

struct BaggageGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    sectionHeader("MAG MEE IN JE HANDBAGAGE", color: Theme.green)
                    ForEach(GuideContent.allowed) { RuleCard(rule: $0) }

                    sectionHeader("MAG NIET MEE IN DE CABINE", color: Theme.red)
                        .padding(.top, Theme.Spacing.sm)
                    ForEach(GuideContent.forbidden) { RuleCard(rule: $0) }

                    disclaimer
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wat mag mee?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.yellow)
                Text("EU-REGELS · SECURITY CHECK")
                    .font(.frutiger(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .kerning(1.6)
            }
            Text("Dit mag wel en niet\nin je handbagage")
                .font(.frutiger(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("De 100 ml regel is sinds 1 september 2024 in de hele EU weer de standaard, ook op luchthavens met nieuwe CT-scanners. Die scanners betekenen alleen dat je spullen vaak in je tas mogen blijven, niet dat er meer mee mag.")
                .font(.frutiger(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.base)
        .background(Theme.inkGradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
                .font(.frutiger(size: 11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .kerning(1.4)
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.sky)
                .font(.system(size: 15))
            Text("Regels kunnen per maatschappij en luchthaven strenger zijn (vooral rond vloeistoffen en powerbanks). Check bij twijfel de detailpagina van je maatschappij in deze app of de site van je luchthaven.")
                .font(.frutiger(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(.top, Theme.Spacing.sm)
    }
}

private struct RuleCard: View {
    let rule: GuideRule
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(rule.status.color.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: rule.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(rule.status.color)
                    }

                    Text(rule.title)
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: rule.status.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(rule.status.label)
                            .font(.frutiger(size: 10, weight: .bold))
                    }
                    .foregroundStyle(rule.status.color)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(rule.status.color.opacity(0.12))
                    .clipShape(Capsule())
                }

                if expanded {
                    Text(rule.text)
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BaggageGuideView()
}
