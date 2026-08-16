import SwiftUI
import ContactsUI
import MessageUI

// MARK: - Contactpicker (systeem-UI, geen Contacts-toestemming nodig)

/// Wrapper om CNContactPickerViewController. Bewust dít systeemscherm i.p.v.
/// zelf CNContactStore uit te lezen: de systeempicker draait buiten-proces,
/// waardoor de app geen NSContactsUsageDescription/toestemming nodig heeft
/// om één contact te kiezen — minder privacy-impact, minder permissie-gedoe.
private struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (CNContact) -> Void
        init(onPick: @escaping (CNContact) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(contact)
        }
    }
}

// MARK: - SMS-compose (systeem-UI)

private struct MessageComposer: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    /// Alleen bij `.sent` — geannuleerd of mislukt telt niet als "iemand
    /// uitgenodigd" voor de Copilot-icoon-ontgrendeling.
    let onSent: () -> Void
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = [recipient]
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSent: onSent, onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onSent: () -> Void
        let onFinish: () -> Void
        init(onSent: @escaping () -> Void, onFinish: @escaping () -> Void) {
            self.onSent = onSent
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            if result == .sent { onSent() }
            onFinish()
        }
    }
}

// MARK: - Profielkaart: vriend uitnodigen met code

/// Kiest een contact uit het adresboek en stuurt een sms met de eigen
/// referral-code. Sinds alle functies gratis zijn is er geen beloning meer
/// aan verbonden — de code dient alleen nog om te zien via wie iemand
/// binnenkomt. Beloof in de teksten dus niets wat de app niet geeft.
struct InviteByContactCard: View {
    private struct Recipient: Identifiable { let id: String }

    @ObservedObject private var referral = ReferralManager.shared
    @State private var showContactPicker = false
    @State private var pendingRecipient: Recipient?
    @State private var showCantMessage = false

    private var code: String { referral.myCode }

    private var messageBody: String {
        "Ik gebruik Vliegtuigtas — nooit meer verrast bij de gate! Alle functies zijn gratis. Vul mijn code \(code) in bij het aanmaken van je profiel: https://apps.apple.com/app/id\(AppStoreInfo.appID)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.inkGradient).frame(width: 40, height: 40)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nodig een vriend uit")
                        .font(.frutiger(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Deel je code — alle functies zijn gratis")
                        .font(.frutiger(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Text(code)
                    .font(.frutiger(size: 16, weight: .black))
                    .foregroundStyle(Theme.navy)
                    .kerning(2)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.navy.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Theme.navy)
                }
                .buttonStyle(.plain)
            }

            Button {
                if MFMessageComposeViewController.canSendText() {
                    showContactPicker = true
                } else {
                    showCantMessage = true
                }
            } label: {
                Label("Kies contactpersoon", systemImage: "person.crop.circle.badge.plus")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.inkGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.md)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .sheet(isPresented: $showContactPicker) {
            ContactPicker { contact in
                if let number = contact.phoneNumbers.first?.value.stringValue {
                    pendingRecipient = Recipient(id: number)
                }
            }
        }
        .sheet(item: $pendingRecipient) { recipient in
            MessageComposer(
                recipient: recipient.id,
                body: messageBody,
                onSent: { ReferralManager.shared.markInvited() },
                onFinish: { pendingRecipient = nil }
            )
        }
        .alert("Geen sms mogelijk op dit toestel", isPresented: $showCantMessage) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Code invullen bij onboarding

/// Compacte, inklapbare "heb je een code?"-sectie — optioneel, dus geen
/// drempel voor wie geen code heeft (zelfde filosofie als de rest van
/// onboarding: alles behalve de kernstap is overslaanbaar).
struct ReferralCodeEntryField: View {
    @State private var isExpanded = false
    @State private var code = ""
    @State private var redeemed = false
    @State private var showInvalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !redeemed {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Label("Heb je een uitnodigingscode?", systemImage: "gift")
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            if redeemed {
                Label("Code ingewisseld — welkom aan boord!", systemImage: "checkmark.seal.fill")
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            } else if isExpanded {
                HStack(spacing: 8) {
                    TextField("bijv. AB12CD", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.frutiger(size: 14))
                        .padding(Theme.Spacing.sm)
                        .background(.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))

                    Button("Inwisselen") {
                        if ReferralManager.shared.redeem(code: code) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            withAnimation { redeemed = true }
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            showInvalid = true
                        }
                    }
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                if showInvalid {
                    Text("Code ongeldig of al gebruikt.")
                        .font(.frutiger(size: 10))
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear { redeemed = ReferralManager.shared.hasRedeemedCode }
    }
}
