import SwiftUI
#if !os(watchOS)
import CoreText
import CoreGraphics
#endif

/// Centrale plek voor het app-lettertype. Op iOS (en iPadOS/visionOS/Catalyst)
/// gebruiken we Frutiger als hoofdfont door de hele app, widgets en Live
/// Activities heen — zakelijker en beter leesbaar dan het ronde systeemfont.
/// Op **watchOS** houden we bewust het native systeemlettertype aan: Frutiger
/// is daar niet nodig en de font-registratie-API's verschillen per platform,
/// dus zo voorkomen we build-problemen. Er zijn twee snitten (Regular en Bold);
/// zwaardere gewichten vallen terug op Bold, lichtere op Regular.
enum AppFont {
    static let regular = "Frutiger"
    static let bold = "FrutigerBold"

    /// Registreert de meegeleverde Frutiger-bestanden in het huidige proces.
    /// Nodig omdat elk target (app + extensies) in een eigen proces draait;
    /// idempotent, dus meerdere keren aanroepen is onschadelijk. Op watchOS
    /// een no-op (daar gebruiken we het systeemlettertype).
    static func register() {
        #if !os(watchOS)
        for file in ["Frutiger", "Frutiger_bold"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf"),
                  let data = try? Data(contentsOf: url),
                  let provider = CGDataProvider(data: data as CFData),
                  let cgFont = CGFont(provider) else { continue }
            CTFontManagerRegisterGraphicsFont(cgFont, nil)
        }
        #endif
    }

    private static func isBold(_ weight: Font.Weight) -> Bool {
        weight == .semibold || weight == .bold || weight == .heavy || weight == .black
    }

    static func psName(for weight: Font.Weight) -> String {
        isBold(weight) ? bold : regular
    }
}

extension Font {
    /// Frutiger die meeschaalt met Dynamic Type (via `relativeTo`).
    /// Drop-in vervanger voor `.system(size:weight:design:.rounded)`.
    /// Op watchOS het native systeemlettertype.
    static func frutiger(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        #if os(watchOS)
        return .system(size: size, weight: weight)
        #else
        return .custom(AppFont.psName(for: weight), size: size, relativeTo: textStyle)
        #endif
    }

    /// Frutiger met een vaste grootte (schaalt niet mee) — voor plekken waar de
    /// afmeting deel is van een tekening of een strak vormgegeven badge.
    static func frutigerFixed(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if os(watchOS)
        return .system(size: size, weight: weight)
        #else
        return .custom(AppFont.psName(for: weight), fixedSize: size)
        #endif
    }
}

#if canImport(UIKit)
import UIKit

extension UIFont {
    /// Frutiger als UIFont — voor UIKit-onderdelen (bijv. CarPlay, tekstvelden).
    static func frutiger(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let bold: Bool = weight == .semibold || weight == .bold || weight == .heavy || weight == .black
        let name = bold ? AppFont.bold : AppFont.regular
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}
#endif
