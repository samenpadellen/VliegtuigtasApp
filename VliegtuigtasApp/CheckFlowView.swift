import SwiftUI

// MARK: - Flow state

enum CheckStep { case airline, dimensions, result }

private var checkerStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.windows.first?.safeAreaInsets.top ?? 50
}

struct CheckFlowView: View {
    var preselected: Airline?

    @StateObject private var airlineStore = AirlineStore()
    @StateObject private var checkStore   = CheckStore()

    @State private var step: CheckStep = .airline
    @State private var selectedAirline: Airline?
    @State private var length: Double = 55
    @State private var width:  Double = 40
    @State private var depth:  Double = 20
    @State private var weight: Double = 10

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Step content – volledig scherm voor stap 2 & 3
            ZStack {
                if step == .airline {
                    VStack(spacing: 0) {
                        header
                        AirlineStepView(
                            airlines: airlineStore.airlines,
                            isLoading: airlineStore.isLoading,
                            selected: selectedAirline
                        ) { airline in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                selectedAirline = airline
                                step = .dimensions
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }

                if step == .dimensions {
                    DimensionsStepView(
                        airline: selectedAirline,
                        length: $length, width: $width,
                        depth: $depth, weight: $weight,
                        isChecking: checkStore.isChecking,
                        error: checkStore.error,
                        topInset: compactNavHeight
                    ) {
                        runCheck()
                    }
                    .ignoresSafeArea(edges: .top)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }

                if step == .result, let result = checkStore.result, let airline = selectedAirline {
                    ResultStepView(
                        result: result,
                        airline: airline,
                        dimensions: (length, width, depth, weight),
                        topInset: compactNavHeight
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            checkStore.result = nil
                            step = .airline
                            selectedAirline = nil
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)

            // Zwevende compacte nav bovenop content (alleen stap 2 & 3)
            if step != .airline {
                compactNav
                    .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .task { await airlineStore.load() }
        .onChange(of: checkStore.result) { _, new in
            if new != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    step = .result
                }
            }
        }
        .onAppear {
            if let pre = preselected {
                selectedAirline = pre
                step = .dimensions
            }
        }
    }

    // MARK: - Header (navy gradient, valt over statusbalk)

    private var header: some View {
        Theme.navyGradient
            .frame(maxWidth: .infinity)
            .frame(height: checkerStatusBarHeight + 70)
            .overlay {
                Circle().fill(.white.opacity(0.04)).frame(width: 160).offset(x: 120, y: -20)
                Circle().fill(.white.opacity(0.03)).frame(width: 100).offset(x: 150, y: 50)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 12) {
                    // Terug-knop
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            switch step {
                            case .airline:    dismiss()
                            case .dimensions:
                                step = .airline
                                selectedAirline = nil
                            case .result:
                                checkStore.result = nil
                                step = .dimensions
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    // Label + voortgangsdots
                    VStack(spacing: 6) {
                        Text(stepLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .kerning(1.0)

                        HStack(spacing: 6) {
                            ForEach([CheckStep.airline, .dimensions, .result], id: \.hashValue) { s in
                                Capsule()
                                    .fill(stepIndex(s) <= stepIndex(step)
                                          ? Color.white
                                          : Color.white.opacity(0.25))
                                    .frame(width: stepIndex(s) == stepIndex(step) ? 22 : 7, height: 7)
                                    .animation(.spring(response: 0.3), value: step)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Symmetrie-placeholder
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }
            .clipped()
    }

    // MARK: - Compact nav hoogte (voor scroll-inset van stap 2 & 3)

    private var compactNavHeight: CGFloat { checkerStatusBarHeight + 50 }

    // MARK: - Compact nav (zwevend, stap 2 & 3)

    private var compactNav: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: checkerStatusBarHeight)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        switch step {
                        case .airline:    dismiss()
                        case .dimensions: step = .airline; selectedAirline = nil
                        case .result:
                            checkStore.result = nil
                            step = .dimensions
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(step == .result ? "Maten" : "Maatschappij")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.navy)
                }

                Spacer()

                // Stap-indicator pills
                HStack(spacing: 5) {
                    ForEach([CheckStep.airline, .dimensions, .result], id: \.hashValue) { s in
                        Capsule()
                            .fill(stepIndex(s) <= stepIndex(step)
                                  ? Theme.navy
                                  : Theme.navy.opacity(0.15))
                            .frame(width: stepIndex(s) == stepIndex(step) ? 18 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 50)

            Divider().opacity(0.4)
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .top)
    }

    private var stepLabel: String {
        switch step {
        case .airline:    return "HANDBAGAGE CHECKER"
        case .dimensions: return "HANDBAGAGE CHECKER"
        case .result:     return "RESULTAAT"
        }
    }

    private func stepIndex(_ s: CheckStep) -> Int {
        switch s { case .airline: return 0; case .dimensions: return 1; case .result: return 2 }
    }

    // MARK: - Actions

    private func runCheck() {
        guard let airline = selectedAirline else { return }
        Task {
            await checkStore.check(
                airlineSlug: airline.slug,
                length: length, width: width, depth: depth, weight: weight
            )
        }
    }
}

extension CheckStep: Hashable {}

// MARK: - Step 1: Airline

private struct AirlineStepView: View {
    let airlines: [Airline]
    let isLoading: Bool
    let selected: Airline?
    let onSelect: (Airline) -> Void

    @State private var search = ""

    private var filtered: [Airline] {
        search.isEmpty ? airlines : airlines.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Met welke\nmaatschappij vlieg je?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Kies je luchtvaartmaatschappij.")
                    .font(.body1).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)

            // Zoekbalk
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.system(size: 15))
                TextField("Zoek maatschappij…", text: $search)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, design: .rounded))
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)

            if isLoading {
                ProgressView().tint(Theme.sky).frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                        spacing: 10
                    ) {
                        ForEach(filtered) { airline in
                            AirlineTile(airline: airline, isSelected: selected?.id == airline.id) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onSelect(airline)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct AirlineTile: View {
    let airline: Airline
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                AirlineLogo(airline: airline, size: 64)
                Text(airline.name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Theme.skyLight : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Theme.sky : .clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: 6, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(.spring(response: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Dimensions

private struct DimensionsStepView: View {
    let airline: Airline?
    @Binding var length: Double
    @Binding var width:  Double
    @Binding var depth:  Double
    @Binding var weight: Double
    let isChecking: Bool
    let error: String?
    var topInset: CGFloat = 0
    let onCheck: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    if let name = airline?.name {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.sky)
                    }
                    Text("Hoe groot is\njouw handbagage?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Meet jouw tas op en vul de maten in.")
                        .font(.body1).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Visual bag diagram
                BagDiagram(length: length, width: width, depth: depth)
                    .padding(.horizontal, 20)

                // Dimension inputs
                Card {
                    VStack(spacing: 14) {
                        DimSlider(label: "Hoogte", value: $length, range: 20...90, color: Theme.navy)
                        Divider()
                        DimSlider(label: "Breedte", value: $width,  range: 10...60, color: Theme.navy)
                        Divider()
                        DimSlider(label: "Diepte",  value: $depth,  range: 5...50,  color: Theme.navy)
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Weight
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "scalemass.fill").foregroundStyle(Theme.navy)
                            Text("Gewicht").font(.headline2)
                        }
                        HStack(spacing: 0) {
                            Button {
                                if weight > 1 { weight = max(1, weight - 0.5) }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28)).foregroundStyle(Theme.navy)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", weight))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text("kilogram").font(.caption1).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Button {
                                if weight < 40 { weight += 0.5 }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28)).foregroundStyle(Theme.navy)
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)

                // Check button
                VStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onCheck()
                    } label: {
                        HStack(spacing: 8) {
                            if isChecking {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(isChecking ? "Controleren…" : "Controleer nu")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(isChecking
                            ? AnyShapeStyle(Theme.navy.opacity(0.5))
                            : AnyShapeStyle(Theme.navyGradient))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Theme.navy.opacity(0.30), radius: 10, x: 0, y: 4)
                    }
                    .disabled(isChecking)

                    if let err = error {
                        Label(err, systemImage: "exclamationmark.circle")
                            .font(.caption1).foregroundStyle(Theme.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .padding(.top, topInset + 8)
        }
    }
}

// MARK: - Bag diagram

private struct BagDiagram: View {
    let length: Double
    let width:  Double
    let depth:  Double

    private let maxW: Double = 80
    private let maxH: Double = 100

    var scaledW: Double { min(maxW, width  / 60 * maxW) }
    var scaledH: Double { min(maxH, length / 90 * maxH) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.skyLight)
                .frame(height: 160)

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Theme.sky.opacity(0.5))
                    .frame(width: 24, height: 8)
                    .offset(y: 4)

                // Bag body
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.yellow)
                        .frame(width: scaledW, height: scaledH)
                        .shadow(color: Theme.yellow.opacity(0.4), radius: 8, x: 0, y: 4)

                    // Stripe lines
                    VStack(spacing: scaledH / 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: scaledW * 0.7, height: 3)
                        }
                    }
                }

                // Wheels
                HStack(spacing: scaledW * 0.35) {
                    Circle().fill(Color.gray).frame(width: 7, height: 7)
                    Circle().fill(Color.gray).frame(width: 7, height: 7)
                }
                .offset(y: -4)
            }

            // Dimension labels
            HStack {
                VStack {
                    Text("\(Int(length)) cm")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.sky)
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption2).foregroundStyle(Theme.sky)
                }
                Spacer()
                VStack {
                    Text("\(Int(width)) cm")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.sky)
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption2).foregroundStyle(Theme.sky)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Dim slider

private struct DimSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body1).fontWeight(.medium)
                .frame(width: 60, alignment: .leading)

            Slider(value: $value, in: range, step: 1) { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .tint(color)

            Text("\(Int(value))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            Text("cm").font(.caption1).foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Step 3: Result

struct ResultStepView: View {
    let result: CheckResponse
    let airline: Airline
    let dimensions: (Double, Double, Double, Double)
    var topInset: CGFloat = 0
    let onReset: () -> Void

    @State private var bags: [Bag] = []
    @State private var loadingBags = false
    @State private var firstName = ""
    @State private var email = ""
    @State private var leadSent = false

    private var isFit: Bool { result.status == "fit" }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Verdict hero
                verdictHero

                // Variant details (compact)
                if let variant = result.variant {
                    variantRow(variant)
                }

                // Tas-aanbevelingen
                if !isFit {
                    bagRecommendations
                }

                // Opnieuw + disclaimer
                VStack(spacing: 16) {
                    Button(action: onReset) {
                        Label("Opnieuw controleren", systemImage: "arrow.clockwise")
                            .font(.body1).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.navy.opacity(0.07))
                            .foregroundStyle(Theme.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Text("Indicatie — controleer altijd de officiële regels.")
                        .font(.caption1).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 36)
            }
            .padding(.top, topInset + 16)
        }
        .task { await loadBags() }
    }

    // MARK: Verdict hero

    private var verdictHero: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.verdictColor(result.verdict).opacity(0.10))
                    .frame(width: 110, height: 110)
                Image(systemName: verdictIcon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Theme.verdictColor(result.verdict))
            }

            VStack(spacing: 8) {
                Text(result.verdictTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    AirlineLogo(airline: airline, size: 20)
                    Text(airline.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 8) {
                    DimPill(value: "\(Int(dimensions.0))×\(Int(dimensions.1))×\(Int(dimensions.2)) cm", icon: "ruler")
                    DimPill(value: String(format: "%.1f kg", dimensions.3), icon: "scalemass")
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
    }

    private var verdictIcon: String {
        switch result.verdict {
        case .ok:      return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail:    return "xmark.circle.fill"
        }
    }

    // MARK: Variant rij (compact)

    private func variantRow(_ variant: CheckVariant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let w = variant.maxWeightKg {
                resultRow(icon: "scalemass", label: "Max gewicht", value: "\(Int(w)) kg")
            }
            if let large = variant.includesLargeBag {
                resultRow(
                    icon: large ? "bag.fill" : "bag",
                    label: "Tickettype",
                    value: large ? "Grote handbagage inbegrepen" : "Alleen klein persoonlijk item",
                    color: large ? Theme.green : Theme.orange
                )
            }
            if let reasons = result.reasons, !reasons.isEmpty {
                ForEach(reasons, id: \.self) { r in
                    resultRow(icon: "exclamationmark.circle", label: r, value: "", color: Theme.red)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func resultRow(icon: String, label: String, value: String, color: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Bag recommendations

    private var bagRecommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tassen die wél passen")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Geselecteerd voor \(airline.name).")
                    .font(.caption1).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)

            if loadingBags {
                ProgressView().tint(Theme.sky).frame(maxWidth: .infinity).padding()
            } else if !bags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(bags.prefix(6)) { bag in
                            BagRecommendationCard(bag: bag)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: Lead card

    private var leadCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Theme.sky)
                    Text("Ontvang de beste tas-tips")
                        .font(.headline2)
                }

                Text("We sturen je een overzicht van tassen die altijd passen bij \(airline.name).")
                    .font(.caption1).foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    TextField("Voornaam", text: $firstName)
                        .textContentType(.givenName)
                        .padding(11)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("E-mail", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(11)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    APIClient.shared.saveLead(firstName: firstName, email: email, airlineSlug: airline.slug)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation { leadSent = true }
                } label: {
                    Text("Stuur mij tips")
                        .font(.body1).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canSendLead ? Theme.sky : Theme.sky.opacity(0.35))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSendLead)
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    private var canSendLead: Bool { !firstName.isEmpty && email.contains("@") }

    // MARK: - Data

    private func loadBags() async {
        guard !isFit else { return }
        loadingBags = true
        bags = (try? await APIClient.shared.bags(airline: airline.slug)) ?? []
        loadingBags = false
    }
}

// MARK: - Bag card (horizontal scroll)

private struct BagRecommendationCard: View {
    let bag: Bag

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: bag.imageUrl.flatMap(URL.init)) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    ZStack {
                        Theme.skyLight
                        Image(systemName: "bag").font(.system(size: 28)).foregroundStyle(Theme.sky.opacity(0.4))
                    }
                }
            }
            .frame(width: 160, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(bag.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                if let brand = bag.brand {
                    Text(brand).font(.caption1).foregroundStyle(Theme.textSecondary)
                }
                if let price = bag.price {
                    Text("€\(String(format: "%.0f", price))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.sky)
                }
            }

            if let url = bag.affiliateUrl.flatMap(URL.init) {
                Link(destination: url) {
                    Text("Bekijk tas")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.sky)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(width: 160)
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Dim pill

private struct DimPill: View {
    let value: String
    let icon: String

    var body: some View {
        Label(value, systemImage: icon)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.card)
            .clipShape(Capsule())
            .foregroundStyle(Theme.textSecondary)
    }
}
