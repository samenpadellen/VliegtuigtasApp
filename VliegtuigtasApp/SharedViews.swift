import SwiftUI

// MARK: - Card

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.navyGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.navy.opacity(0.30), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Authenticated image loader

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private static var cache = NSCache<NSString, UIImage>()

    func load(_ urlString: String) {
        let key = urlString as NSString
        if let cached = Self.cache.object(forKey: key) {
            image = cached; return
        }
        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer lFkEQW18oyMrdMsbfNK1DtnDnoCcqwNSBRfMCXmszUgbAoLf",
                     forHTTPHeaderField: "Authorization")
        Task {
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let img = UIImage(data: data) else { return }
            Self.cache.setObject(img, forKey: key)
            image = img
        }
    }
}

struct AuthorisedImage: View {
    let urlString: String?
    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: urlString) {
            if let s = urlString { loader.load(s) }
        }
    }
}

// MARK: - Airline logo

struct AirlineLogo: View {
    let airline: Airline
    let size: CGFloat

    var body: some View {
        Group {
            if airline.bestLogoUrl != nil {
                AuthorisedImage(urlString: airline.bestLogoUrl)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size * 0.6)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Theme.skyLight)
            Text(airline.name.prefix(2).uppercased())
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.sky)
        }
    }
}

// MARK: - Verdict badge

struct VerdictBadge: View {
    let verdict: Verdict
    let message: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
            if let msg = message {
                Text(msg).font(.body1).multilineTextAlignment(.leading)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.verdictColor(verdict))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var iconName: String {
        switch verdict {
        case .ok:      return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail:    return "xmark.circle.fill"
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline2)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Number stepper field

struct MeasurementField: View {
    let label: String
    let unit: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption1).foregroundStyle(Theme.textSecondary)
            HStack {
                Button { value = max(range.lowerBound, value - step) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2).foregroundStyle(Theme.sky)
                }
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Button { value = min(range.upperBound, value + step) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2).foregroundStyle(Theme.sky)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Loading spinner overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.5)
        }
    }
}
