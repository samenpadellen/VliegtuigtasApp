import SwiftUI
import CoreText
import CoreGraphics

/// Centrale plek voor het app-lettertype. We gebruiken Frutiger als hoofdfont
/// door de hele app, widgets en Live Activities heen — zakelijker en beter
/// leesbaar dan het ronde systeemlettertype. Er zijn twee snitten (Regular en
/// Bold); zwaardere gewichten vallen terug op Bold, lichtere op Regular.
enum AppFont {
    static let regular = "Frutiger"
    static let bold = "FrutigerBold"

    /// Registreert de meegeleverde Frutiger-bestanden in het huidige proces.
    /// Nodig omdat elk target (app + extensies) in een eigen proces draait;
    /// idempotent, dus meerdere keren aanroepen is onschadelijk.
    ///
    /// Bewust de CGFont-variant (`CTFontManagerRegisterGraphicsFont`): de
    /// URL-variant bestaat niet op watchOS, deze werkt op álle platforms.
    static func register() {
        for file in ["Frutiger", "Frutiger_bold"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf"),
                  let data = try? Data(contentsOf: url),
                  let provider = CGDataProvider(data: data as CFData),
                  let cgFont = CGFont(provider) else { continue }
            CTFontManagerRegisterGraphicsFont(cgFont, nil)
        }
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
    static func frutiger(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom(AppFont.psName(for: weight), size: size, relativeTo: textStyle)
    }

    /// Frutiger met een vaste grootte (schaalt niet mee) — voor plekken waar de
    /// afmeting deel is van een tekening of een strak vormgegeven badge.
    static func frutigerFixed(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(AppFont.psName(for: weight), fixedSize: size)
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
