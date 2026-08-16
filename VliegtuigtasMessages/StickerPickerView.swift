import SwiftUI

/// Eén sticker uit de bestaande set (hergebruikt uit `VliegtuigtasStickers`,
/// nu ingebed in deze interactieve extensie — iOS staat maar één
/// `com.apple.message-payload-provider`-extensie per app toe, dus de losse
/// sticker-only extensie en deze bagagecheck-extensie konden niet naast
/// elkaar bestaan).
struct StickerItem: Identifiable {
    let id: String
    let filename: String
    let displayName: String
}

enum StickerCatalog {
    static let all: [StickerItem] = [
        .init(id: "pim", filename: "pim", displayName: "Purser Pim"),
        .init(id: "boarding", filename: "boarding", displayName: "Boarding"),
        .init(id: "gate", filename: "gate", displayName: "Gate"),
        .init(id: "vertrek", filename: "vertrek", displayName: "Vertrek"),
        .init(id: "optijd", filename: "optijd", displayName: "Op tijd"),
        .init(id: "vertraagd", filename: "vertraagd", displayName: "Vertraagd"),
        .init(id: "ingechecked", filename: "ingechecked", displayName: "Ingecheckt"),
        .init(id: "bagage", filename: "bagage", displayName: "Bagage"),
        .init(id: "goedereis", filename: "goedereis", displayName: "Goede reis"),
        .init(id: "flap", filename: "flap", displayName: "Klapperbord"),
    ]
}

struct StickerPickerView: View {
    let onSend: (StickerItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.md)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(StickerCatalog.all) { item in
                    Button {
                        onSend(item)
                    } label: {
                        VStack(spacing: Theme.Spacing.xxs) {
                            stickerImage(for: item)
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                            Text(item.displayName)
                                .font(.frutiger(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.base)
        }
        .background(Theme.surface)
    }

    @ViewBuilder
    private func stickerImage(for item: StickerItem) -> some View {
        if let url = Bundle.main.url(forResource: item.filename, withExtension: "png"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.skyLight)
        }
    }
}
