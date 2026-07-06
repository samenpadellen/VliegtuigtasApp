import SwiftUI

/// Profiel: persoonsgegevens inzien, eigen tas en vlucht bekijken en
/// uitloggen. Bereikbaar via de naam-chip op Home.
struct ProfileView: View {
    @EnvironmentObject private var session: UserSession
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var bagCollection = BagCollectionStore.shared
    @State private var editingBag: SavedBag?
    @State private var showNewBag = false
    @State private var showBagsOverview = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    personalDataCard

                    sectionTitle("Mijn tassen & koffers")
                    bagsSection

                    sectionTitle("Mijn vluchten")
                    MyFlightsSection()

                    #if !targetEnvironment(macCatalyst)
                    sectionTitle("App-icoon")
                    AppIconPicker()
                    #endif

                    sectionTitle("Functies op dit toestel")
                    featuresCard

                    sectionTitle("Beoordeel de app")
                    ReviewInviteCard()

                    logoutButton

                    deleteAccountButton
                }
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mijn profiel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var initials: String {
        let parts = session.firstName.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "✈︎" : String(letters).uppercased()
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.navyGradient)
                    .frame(width: 76, height: 76)
                Text(initials)
                    .font(.frutiger(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(session.firstName.isEmpty ? "Reiziger" : session.firstName)
                .font(.frutiger(size: 20, weight: .bold))
        }
        .padding(.top, 8)
    }

    // MARK: - Persoonsgegevens

    private var personalDataCard: some View {
        VStack(spacing: 0) {
            profileRow(icon: "person.fill", label: "Naam",
                       value: session.firstName.isEmpty ? "—" : session.firstName)
            Divider().padding(.leading, 44)
            profileRow(icon: "envelope.fill", label: "E-mail",
                       value: session.email.isEmpty ? "—" : session.email)
            Divider().padding(.leading, 44)
            HStack(spacing: 12) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sky)
                    .frame(width: 20)
                Text("Je gegevens, tasmaten en vlucht syncen via iCloud naar je andere Apple-apparaten. Er is geen apart account.")
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 11)
        }
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.navy)
                .frame(width: 20)
            Text(label)
                .font(.frutiger(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.frutiger(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Mijn tassen & koffers

    private var bagsSection: some View {
        VStack(spacing: 10) {
            ForEach(bagCollection.bags) { bag in
                Button {
                    editingBag = bag
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "suitcase.rolling.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.yellow)
                            .frame(width: 40, height: 40)
                            .background(Theme.yellow.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bag.name)
                                .font(.frutiger(size: 15, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(bag.dimsLabel) · \(bag.weight.formatted()) kg")
                                .font(.frutiger(size: 12))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    showNewBag = true
                } label: {
                    Label("Toevoegen", systemImage: "plus")
                        .font(.frutiger(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.navy.opacity(0.07))
                        .foregroundStyle(Theme.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if !bagCollection.bags.isEmpty {
                    Button {
                        showBagsOverview = true
                    } label: {
                        Label("Past dit?", systemImage: "checkmark.shield.fill")
                            .font(.frutiger(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Theme.navyGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $editingBag) { bag in
            BagEditorSheet(bag: bag)
        }
        .sheet(isPresented: $showNewBag) {
            BagEditorSheet(bag: nil)
        }
        .sheet(isPresented: $showBagsOverview) {
            MyBagsOverviewView()
        }
    }

    // MARK: - Functies op dit toestel

    /// Hardware-afhankelijke features met hun status, zodat gebruikers
    /// zien waarom iets op hún toestel wel of niet beschikbaar is.
    private var featuresCard: some View {
        VStack(spacing: 0) {
            featureRow(
                icon: "camera.viewfinder",
                title: "AR tasmeting (LiDAR)",
                available: LiDARSupport.isAvailable,
                detail: LiDARSupport.isAvailable
                    ? "Beschikbaar"
                    : "Toestel beschikt niet over de vereiste hardware"
            )
            Divider().padding(.leading, 44)
            pimFeatureRow
        }
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var pimFeatureRow: some View {
        if #available(iOS 26.0, *) {
            featureRow(
                icon: "person.crop.circle",
                title: "Purser Pim (Apple Intelligence)",
                available: AIAvailability.isAvailable,
                detail: AIAvailability.isAvailable
                    ? "Beschikbaar"
                    : (AIAvailability.unavailableReason ?? "Niet beschikbaar")
            )
        } else {
            featureRow(
                icon: "person.crop.circle",
                title: "Purser Pim (Apple Intelligence)",
                available: false,
                detail: "Vereist iOS 26 of nieuwer"
            )
        }
    }

    private func featureRow(icon: String, title: String, available: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(available ? Theme.navy : Theme.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(available ? Theme.textPrimary : Theme.textSecondary)
                Text(detail)
                    .font(.frutiger(size: 11))
                    .foregroundStyle(available ? Theme.green : Theme.textSecondary)
            }
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: 15))
                .foregroundStyle(available ? Theme.green : Theme.textSecondary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Bouwstenen

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.frutiger(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var logoutButton: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            Text("Uitloggen")
                .font(.frutiger(size: 15, weight: .semibold))
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .confirmationDialog(
            "Uitloggen?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Uitloggen", role: .destructive) {
                session.reset()
                dismiss()
            }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Je naam en e-mail worden van dit toestel en uit iCloud verwijderd. Je opgeslagen vlucht en tasmaten blijven staan.")
        }
    }

    /// Volledige accountverwijdering (App Review 5.1.1(v)): wist álles —
    /// lokaal, iCloud én een verwijderverzoek voor de servergegevens.
    private var deleteAccountButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            VStack(spacing: 3) {
                Text("Account & gegevens verwijderen")
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.red)
                Text("Verwijdert alles, ook uit iCloud en van onze server")
                    .font(.frutiger(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Account en alle gegevens definitief verwijderen?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Verwijder alles definitief", role: .destructive) {
                let email = session.email
                if !email.isEmpty {
                    // Verwijderverzoek voor de servergegevens (lead).
                    APIClient.shared.requestAccountDeletion(email: email)
                }
                SharedFlightStore.clearFlight()
                FlightsStore.shared.removeAll()
                CloudSync.shared.clearFlightList()
                FlightLiveActivityManager.shared.sync()
                CloudSync.shared.clearBagDims()
                BagCollectionStore.shared.removeAll()
                CloudSync.shared.clearBagList()
                session.reset()
                dismiss()
            }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Dit verwijdert je naam, e-mail, tasmaten en opgeslagen vlucht van dit toestel, uit iCloud en van onze server. Dit kan niet ongedaan worden gemaakt.")
        }
    }
}

// MARK: - Profiel-gate voor accountgebonden features

/// Uitleg + mini-registratie voor features die een profiel vereisen.
/// De reden is altijd functioneel: de data van deze features is
/// profielgebonden (iCloud-sync naar widgets/Watch/andere apparaten,
/// persoonlijke notificaties, en wissen bij accountverwijdering).
struct AccountRequiredView: View {
    let icon: String
    let title: String
    let reason: String
    /// Aangeroepen ná de succes-animatie: sluit de sheet en open de feature
    /// waarvoor het profiel gemaakt werd.
    var onCompleted: (() -> Void)? = nil

    @ObservedObject private var session = UserSession.shared
    @State private var name = ""
    @State private var email = ""
    @State private var showError = false
    @State private var completed = false

    var body: some View {
        VStack(spacing: 0) {
            // Donkere hero: dezelfde premium stijl als de onboarding, zodat
            // een profiel aanmaken als een upgrade voelt en niet als drempel.
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.yellow)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(title)
                        .font(.frutiger(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(reason)
                    .font(.frutiger(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    benefit("Synct automatisch naar iPhone, iPad, Mac en Watch")
                    benefit("Persoonlijke reminders en aftelling naar vertrek")
                    benefit("Purser Pim kent jouw tas en vlucht")
                    benefit("Gratis, zonder wachtwoord, in 10 seconden geregeld")
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.navyGradient)

            // Formulier op wit: twee velden en klaar. Na aanmaken: duidelijke
            // succes-state, daarna gaat de flow automatisch verder.
            if completed {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Theme.green)
                        .transition(.scale.combined(with: .opacity))
                    Text("Welkom aan boord\(session.firstName.isEmpty ? "" : ", \(session.firstName)")!")
                        .font(.frutiger(size: 17, weight: .bold))
                    Text("Je profiel staat klaar.")
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(.systemBackground))
            } else {
                formSection
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Theme.navy.opacity(0.15), radius: 14, x: 0, y: 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: completed)
    }

    private var formSection: some View {
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    TextField("Voornaam", text: $name)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                        .font(.frutiger(size: 15))
                        .padding(13)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    TextField("E-mailadres", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.frutiger(size: 15))
                        .padding(13)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if showError {
                    Label("Vul je voornaam en een geldig e-mailadres in", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    let trimmedName = name.trimmingCharacters(in: .whitespaces)
                    let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
                    guard !trimmedName.isEmpty, trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
                        showError = true
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        return
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    session.completeOnboarding(firstName: trimmedName, email: trimmedEmail)
                    // Zichtbare bevestiging, daarna automatisch door naar de
                    // feature waarvoor het profiel gemaakt werd.
                    withAnimation { completed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onCompleted?()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Maak gratis profiel")
                            .font(.frutiger(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.navyGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Text("Verwijderen kan altijd via je profiel. Dan wissen we alles, ook uit iCloud en van onze server.")
                    .font(.frutiger(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color(.systemBackground))
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.yellow)
                .padding(.top, 1)
            Text(text)
                .font(.frutiger(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserSession.shared)
}
