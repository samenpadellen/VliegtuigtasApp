import Foundation

/// Vriend uitnodigen met een persoonlijke code.
///
/// Sinds alle functies gratis zijn is er geen beloning meer aan verbonden: de
/// code houdt alleen bij dát iemand via een ander is binnengekomen. Vroeger
/// gaf een ingewisselde code 1 maand Vliegtuigtas Pro; `bonusExpiry` en
/// `hasActiveBonus` zijn daar nog van over en ontgrendelen niets meer.
///
/// De verwijzer krijgt geen geautomatiseerde beloning terug: dat vereist een
/// backend-endpoint dat kan matchen "toestel B heeft code van toestel A
/// ingewisseld", en vliegtuigtas.com heeft dat endpoint niet.
@MainActor
final class ReferralManager: ObservableObject {
    static let shared = ReferralManager()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let myCode = "vt_referral_code"
        static let redeemedCode = "vt_redeemed_referral_code"
        static let bonusExpiry = "vt_referral_bonus_expiry"
        static let hasInvited = "vt_has_invited"
    }

    @Published private(set) var bonusExpiry: Date?
    /// Gezet zodra een uitnodigings-sms daadwerkelijk verstuurd is (niet bij
    /// annuleren) — ontgrendelt het exclusieve "Copilot"-app-icoon.
    @Published private(set) var hasInvited: Bool

    private init() {
        let t = defaults.double(forKey: Key.bonusExpiry)
        if t > 0 { bonusExpiry = Date(timeIntervalSince1970: t) }
        hasInvited = defaults.bool(forKey: Key.hasInvited)
    }

    func markInvited() {
        guard !hasInvited else { return }
        hasInvited = true
        defaults.set(true, forKey: Key.hasInvited)
        APIClient.shared.sendEvent("referral_invite_sent", path: "/referral")
    }

    /// Stabiele, deelbare code voor deze installatie — 6 tekens, zonder
    /// karakters die op elkaar lijken (0/O, 1/I).
    var myCode: String {
        if let existing = defaults.string(forKey: Key.myCode) { return existing }
        let code = Self.generateCode()
        defaults.set(code, forKey: Key.myCode)
        return code
    }

    var hasRedeemedCode: Bool {
        defaults.string(forKey: Key.redeemedCode) != nil
    }

    var hasActiveBonus: Bool {
        guard let bonusExpiry else { return false }
        return bonusExpiry > .now
    }

    /// Eén keer per installatie inwisselbaar. Geeft false terug bij een lege
    /// code, een al ingewisselde code, of een poging de eigen code te
    /// gebruiken (voorkomt de meest voor de hand liggende misbruikpoging).
    @discardableResult
    func redeem(code raw: String) -> Bool {
        let code = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty, code != myCode, !hasRedeemedCode else { return false }
        defaults.set(code, forKey: Key.redeemedCode)
        let expiry = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
        bonusExpiry = expiry
        defaults.set(expiry.timeIntervalSince1970, forKey: Key.bonusExpiry)
        APIClient.shared.sendEvent("referral_redeemed", path: "/referral")
        return true
    }

    private static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }
}
