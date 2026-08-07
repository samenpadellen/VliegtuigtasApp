import SwiftUI
import AuthenticationServices
import Security

// MARK: - Keychain (minimaal, alleen wat we nodig hebben)

/// Bewaart de stabiele Apple-gebruikers-ID los van UserDefaults: overleeft
/// een herinstallatie, precies zoals Apple voor Sign in with Apple adviseert.
enum Keychain {
    private static let service = "com.vliegtuigtas.app.applesignin"

    static func set(_ value: String, for key: String) {
        remove(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Sign in with Apple-knop

/// Wrapper om de native SwiftUI-knop: bij succes vult dit direct het profiel
/// (UserSession) — geen los formulier nodig, Apple levert naam + e-mail.
struct AppleSignInButton: View {
    var style: SignInWithAppleButton.Style = .white
    /// Aangeroepen ná een geslaagde koppeling — zodat aanroepers (onboarding,
    /// het profiel-gate-formulier) hun eigen succes-animatie/vervolgstap
    /// kunnen tonen, net als na het handmatige formulier.
    var onSuccess: (() -> Void)? = nil

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                UserSession.shared.completeWithApple(
                    userId: credential.user,
                    firstName: fullName.isEmpty ? nil : fullName,
                    email: credential.email
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSuccess?()
            case .failure:
                // Geannuleerd of mislukt — de handmatige velden en "Sla over"
                // blijven gewoon beschikbaar, dus geen foutmelding nodig.
                break
            }
        }
        .signInWithAppleButtonStyle(style)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
