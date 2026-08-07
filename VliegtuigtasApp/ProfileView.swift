import SwiftUI

/// Profiel: persoonsgegevens inzien, eigen tas en vlucht bekijken en
/// uitloggen. Bereikbaar via de naam-chip op Home.
struct ProfileView: View {
    @EnvironmentObject private var session: UserSession
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var bagCollection = BagCollectionStore.shared
    @ObservedObject private var flights = FlightsStore.shared
    @State private var editingBag: SavedBag?
    @State private var showNewBag = false
    @State private var showBagsOverview = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showEditProfile = false

    // Easteregg: 5× snel op de streepjescode tikken → inspectiestempel van
    // Purser Pim. Zusje van de schud-easteregg op het klapperbord (Home).
    @State private var barcodeTapCount = 0
    @State private var lastBarcodeTap = Date.distantPast
    @State private var showStamp = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Button {
                        showEditProfile = true
                    } label: {
                        baggageTag
                    }
                    .buttonStyle(.plain)

                    sectionTitle("Mijn tassen & koffers")
                    bagsSection

                    // "Mijn vluchten" staat sinds 3.0.0 in de Reizen-tab: een
                    // reisfunctie hoort niet tussen de accountinstellingen.

                    #if !targetEnvironment(macCatalyst)
                    sectionTitle("App-icoon")
                    AppIconPicker()
                    #endif

                    sectionTitle("Functies op dit toestel")
                    featuresCard

                    sectionTitle("Beoordeel de app")
                    ReviewInviteCard()

                    sectionTitle("Deel Vliegtuigtas")
                    InviteByContactCard()

                    sectionTitle("Account")
                    accountMethodRow

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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Label("Bewerken", systemImage: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                ProfileEditorSheet()
            }
        }
    }

    // MARK: - Bagagelabel (kop)

    /// Seed voor labelnummer + streepjescode: stabiel per gebruiker.
    private var tagSeed: String {
        if !session.email.isEmpty { return session.email }
        if !session.firstName.isEmpty { return session.firstName }
        return "vliegtuigtas"
    }
    private var passengerName: String {
        session.firstName.isEmpty ? "REIZIGER" : session.firstName.uppercased()
    }
    private var nextFlight: SavedFlightRecord? { flights.next }
    private var fromCode: String { nextFlight?.departureIata?.uppercased() ?? "—" }
    private var toCode: String { nextFlight?.arrivalIata?.uppercased() ?? "—" }
    private var seqNumber: String {
        var g = SeededGen(tagSeed + "-seq")
        return String(format: "%03d", g.int(1...999))
    }
    private var tagNumber: String {
        var g = SeededGen(tagSeed)
        return String(format: "0%03d %06d", g.int(100...999), g.int(0...999_999))
    }
    /// Gedeeld en gecachet i.p.v. per render een nieuwe `DateFormatter()`
    /// aan te maken (die instantiatie is relatief kostbaar).
    private static let tagDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "dd MMM"
        return f
    }()
    private var tagDate: String {
        Self.tagDateFormatter.string(from: nextFlight?.departure ?? Date()).uppercased()
    }
    /// Easteregg: "—" tot je de streepjescode-stempel activeert, daarna de
    /// datum waarop dat gebeurde — een minuscuul hintje dat pas betekenis
    /// krijgt zodra je de stempel al eens gevonden hebt.
    private var approvedValue: String {
        guard let date = session.barcodeApprovalDate else { return "—" }
        return Self.tagDateFormatter.string(from: date).uppercased()
    }

    private var baggageTag: some View {
        TagPaper(corner: 22) {
            VStack(spacing: 0) {
                tagHeader
                tagBody
                TagPerforation()
                    .padding(.horizontal, 18)
                personalStubContent
            }
        }
        .overlay {
            if showStamp { pimStamp.transition(.asymmetric(
                insertion: .scale(scale: 1.6).combined(with: .opacity),
                removal: .opacity
            )) }
        }
    }

    // MARK: - Easteregg: inspectiestempel

    /// 5× snel tikken op de streepjescode → Purser Pim "keurt" je label goed.
    /// Trager dan 1,2s tussen tikken telt niet mee, zodat toevallig dubbeltikken
    /// het niet per ongeluk triggert.
    private func handleBarcodeTap() {
        let now = Date()
        if now.timeIntervalSince(lastBarcodeTap) > 1.2 { barcodeTapCount = 0 }
        lastBarcodeTap = now
        barcodeTapCount += 1
        guard barcodeTapCount >= 5 else { return }
        barcodeTapCount = 0
        guard !showStamp else { return }
        session.markBarcodeApproved()
        EasterEggStore.shared.discover(.barcodeStamp)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { showStamp = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeOut(duration: 0.35)) { showStamp = false }
        }
    }

    /// Rubberstempel-look: scheve rode ring met "GOEDGEKEURD" + Pim's naam,
    /// zoals een inspectiestempel op een echt bagagelabel.
    private var pimStamp: some View {
        VStack(spacing: 3) {
            Text("GOEDGEKEURD")
                .font(.frutiger(size: 15, weight: .black))
                .kerning(1.5)
            Text("★ PURSER PIM ★")
                .font(.frutiger(size: 9, weight: .bold))
                .kerning(1.5)
        }
        .foregroundStyle(Theme.red)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.red, lineWidth: 2.5)
        )
        .background(Color(.systemBackground).opacity(0.001)) // houdt hit-testing/animatie soepel
        .rotationEffect(.degrees(-10))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Navy/sky-verloop kop met ophangoog, wordmark en een compacte
    /// statuspil (i.p.v. de vorige zware, volle-breedte kleurstrook).
    private var tagHeader: some View {
        HStack(spacing: 12) {
            punchHole
            Text("VLIEGTUIGTAS")
                .font(.frutiger(size: 13, weight: .bold))
                .kerning(2)
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 5) {
                Text(nextFlight != nil ? "PRIORITY" : "PASSAGIER")
                    .kerning(0.6)
                Text("· SEQ \(seqNumber)")
                    .opacity(0.85)
            }
            .font(.frutiger(size: 9, weight: .bold))
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(TagPalette.accent)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.inkGradient)
    }

    /// Het gereinforceerde ophangoog van het label.
    private var punchHole: some View {
        Circle()
            .strokeBorder(.white.opacity(0.55), lineWidth: 2)
            .frame(width: 16, height: 16)
            .overlay(Circle().fill(Theme.navyDark).frame(width: 7, height: 7))
    }

    private var tagBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("PASSAGIER")
                    .printed(9, weight: .bold, soft: true).kerning(1)
                Text(passengerName)
                    .printed(26, weight: .bold)
                    .minimumScaleFactor(0.5).lineLimit(1)
            }

            HStack(alignment: .top, spacing: 10) {
                TagField(label: "FROM", value: fromCode)
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.sky)
                    .padding(.top, 12)
                TagField(label: "TO", value: toCode)
                TagField(label: "FLIGHT", value: nextFlight?.number.uppercased() ?? "—")
            }
            HStack(alignment: .top, spacing: 10) {
                TagField(label: "PCS", value: "\(bagCollection.bags.count)")
                // "APPROVED" staat er standaard al, leeg — pas nadat je de
                // streepjescode-stempel hebt gevonden verschijnt hier een
                // datum. Een minuscuul hintje voor wie goed kijkt.
                TagField(label: "APPROVED", value: approvedValue)
                Spacer()
            }

            VStack(spacing: 10) {
                Barcode(seed: tagSeed, height: 30)
                    .overlay(alignment: .trailing) {
                        // Blijvend vinkje na de stempel: teken dat dit label
                        // ooit is "goedgekeurd", ook nadat de stempelanimatie
                        // allang is weggefade.
                        if session.barcodeApprovalDate != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.green)
                                .padding(.leading, 8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                    // `highPriorityGesture` i.p.v. `onTapGesture`: het hele
                    // label zit al in een Button (tik = bewerken). Zonder
                    // prioriteit zou die Button de tik onderscheppen vóórdat
                    // de tikteller ooit 5 haalt.
                    .highPriorityGesture(TapGesture().onEnded(handleBarcodeTap))
                HStack {
                    Text(tagNumber).printed(13, weight: .bold).kerning(1)
                    Spacer()
                    Text(tagDate).printed(11, weight: .semibold, soft: true)
                }
            }
        }
        .padding(18)
    }

    // MARK: - PAX-strook (persoonsgegevens onder de perforatie)

    private var personalStubContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PAX RECEIPT")
                    .printed(8, weight: .bold, soft: true).kerning(1.5)
                Spacer()
                if session.isSignedInWithApple {
                    Label("APPLE ID", systemImage: "person.badge.key.fill")
                        .printed(8, weight: .bold, soft: true).kerning(1)
                } else {
                    Label("iCLOUD SYNC", systemImage: "icloud.fill")
                        .printed(8, weight: .bold, soft: true).kerning(1)
                }
            }
            TagField(label: "NAME", value: session.firstName.isEmpty ? "—" : session.firstName)
            TagField(label: "E-MAIL", value: session.email.isEmpty ? "—" : session.email)
            Text(session.isSignedInWithApple
                 ? "Ingelogd met Apple. Je gegevens, tasmaten en vlucht syncen ook via iCloud naar je andere Apple-apparaten."
                 : "Je gegevens, tasmaten en vlucht syncen via iCloud naar je andere Apple-apparaten — geen apart wachtwoord nodig.")
                .printed(9, soft: true)
                .fixedSize(horizontal: false, vertical: true)

            // Bewerk-affordance: duidelijk dat het label aanpasbaar is.
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .bold))
                Text(session.firstName.isEmpty && session.email.isEmpty
                     ? "NAAM & E-MAIL INVULLEN"
                     : "GEGEVENS BEWERKEN")
                    .printed(9, weight: .bold).kerning(1)
            }
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Theme.sky.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 2)
        }
        .padding(18)
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
                            .background(Theme.inkGradient)
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

    /// Sectiekop in de stijl van een gedrukt labelveld: monospace, gespatieerd,
    /// met een gestippelde scheurlijn erachter. Blijft adaptief (leesbaar in
    /// licht én donker), want deze staat buiten het papier.
    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize()
            DashedRule()
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    /// Laat zien hoe je bent ingelogd — via Sign in with Apple of met een
    /// zelf ingevuld profiel — zodat de accountsectie duidelijk maakt wat er
    /// aan je gegevens hangt.
    private var accountMethodRow: some View {
        HStack(spacing: 12) {
            Image(systemName: session.isSignedInWithApple ? "apple.logo" : "person.crop.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.navy)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.isSignedInWithApple ? "Ingelogd met Apple" : "Profiel op dit toestel")
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(session.email.isEmpty ? "Naam en e-mail zijn optioneel" : session.email)
                    .font(.frutiger(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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

// MARK: - Naam & e-mail bewerken

/// Laat de gebruiker zijn naam en e-mail invullen of aanpassen. Slaat op via
/// dezelfde weg als de onboarding (lokaal + iCloud), zodat widgets, Watch en
/// andere apparaten meteen mee zijn.
struct ProfileEditorSheet: View {
    @ObservedObject private var session = UserSession.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var showError = false
    @State private var hasPassportDate = false
    @State private var passportDate = Calendar.current.date(byAdding: .year, value: 5, to: .now) ?? .now

    private var isValid: Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        let e = email.trimmingCharacters(in: .whitespaces)
        return !n.isEmpty && e.contains("@") && e.contains(".")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Je gegevens reizen via iCloud mee naar je widget, Apple Watch en al je andere apparaten. Geen wachtwoord nodig.")
                        .font(.frutiger(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        field(title: "Voornaam", text: $name, content: .givenName,
                              keyboard: .default, autocaps: .words)
                        field(title: "E-mailadres", text: $email, content: .emailAddress,
                              keyboard: .emailAddress, autocaps: .never)
                    }

                    if showError {
                        Label("Vul je voornaam en een geldig e-mailadres in",
                              systemImage: "exclamationmark.circle.fill")
                            .font(.frutiger(size: 12))
                            .foregroundStyle(Theme.red)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $hasPassportDate.animation()) {
                            Text("Paspoort vervaldatum bewaren")
                                .font(.frutiger(size: 14, weight: .semibold))
                        }
                        .tint(Theme.navy)
                        if hasPassportDate {
                            DatePicker("Vervaldatum", selection: $passportDate, displayedComponents: .date)
                                .font(.frutiger(size: 14))
                            Text("Zo waarschuwen we je als een geplande reis binnen de gangbare 6-maanden-geldigheidsregel valt.")
                                .font(.frutiger(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(action: save) {
                        Text("Opslaan")
                            .font(.frutiger(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.inkGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mijn gegevens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleer") { dismiss() }
                }
            }
        }
        .onAppear {
            name = session.firstName
            email = session.email
            if let expiry = session.passportExpiry {
                hasPassportDate = true
                passportDate = expiry
            }
        }
    }

    private func field(
        title: String, text: Binding<String>,
        content: UITextContentType, keyboard: UIKeyboardType,
        autocaps: TextInputAutocapitalization
    ) -> some View {
        TextField(title, text: text)
            .textContentType(content)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocaps)
            .autocorrectionDisabled()
            .font(.frutiger(size: 15))
            .padding(13)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func save() {
        guard isValid else {
            showError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        session.completeOnboarding(
            firstName: name.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces)
        )
        session.setPassportExpiry(hasPassportDate ? passportDate : nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
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
            .background(Theme.inkGradient)

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
                AppleSignInButton(style: .black) {
                    withAnimation { completed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onCompleted?()
                    }
                }

                HStack(spacing: 10) {
                    Rectangle().fill(Theme.textSecondary.opacity(0.2)).frame(height: 1)
                    Text("of handmatig")
                        .font(.frutiger(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                    Rectangle().fill(Theme.textSecondary.opacity(0.2)).frame(height: 1)
                }

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
                    .background(Theme.inkGradient)
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
