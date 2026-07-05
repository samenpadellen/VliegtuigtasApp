import SwiftUI

/// De op de watch opgeslagen tasafmetingen. Bewust watch-lokaal (UserDefaults):
/// de iOS-app bewaart geen tasmaten, dus er valt niets te syncen.
@MainActor
final class WatchBagStore: ObservableObject {
    static let shared = WatchBagStore()

    @Published var length: Double { didSet { save() } }
    @Published var width:  Double { didSet { save() } }
    @Published var depth:  Double { didSet { save() } }
    @Published var weight: Double { didSet { save() } }

    private let defaults = UserDefaults.standard
    private enum Key {
        static let length = "vtw_bag_length"
        static let width  = "vtw_bag_width"
        static let depth  = "vtw_bag_depth"
        static let weight = "vtw_bag_weight"
    }

    private init() {
        // Defaults: gangbare cabin-bag maten als startpunt.
        length = defaults.object(forKey: Key.length) as? Double ?? 55
        width  = defaults.object(forKey: Key.width)  as? Double ?? 40
        depth  = defaults.object(forKey: Key.depth)  as? Double ?? 20
        weight = defaults.object(forKey: Key.weight) as? Double ?? 8
    }

    private func save() {
        defaults.set(length, forKey: Key.length)
        defaults.set(width,  forKey: Key.width)
        defaults.set(depth,  forKey: Key.depth)
        defaults.set(weight, forKey: Key.weight)
    }

    var dimsLabel: String {
        "\(Int(length)) × \(Int(width)) × \(Int(depth)) cm · \(weight.clean) kg"
    }

    /// Oriëntatie-onafhankelijke indicatie of de tas binnen de limieten past.
    /// Geen vervanging van de server-check, maar snel genoeg voor op de pols.
    func fits(l: Double?, w: Double?, d: Double?) -> Bool? {
        guard let l, let w, let d else { return nil }
        let bag = [length, width, depth].sorted(by: >)
        let lim = [l, w, d].sorted(by: >)
        return bag[0] <= lim[0] && bag[1] <= lim[1] && bag[2] <= lim[2]
    }

    func fitsWeight(_ maxKg: Double?) -> Bool? {
        maxKg.map { weight <= $0 }
    }
}

extension Double {
    /// "8" i.p.v. "8.0", maar "7.5" blijft "7.5".
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}
