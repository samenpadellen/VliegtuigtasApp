import UIKit
import Messages
import SwiftUI

final class MessagesViewController: MSMessagesAppViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        AppFont.register()
        embedPicker()
    }

    private func embedPicker() {
        let root = MessagesRootView(
            onSendBaggage: { [weak self] airline, variant in
                self?.sendBaggageCard(airline: airline, variant: variant)
            },
            onSendSticker: { [weak self] item in
                self?.sendSticker(item)
            }
        )
        let hosting = UIHostingController(rootView: root)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }

    /// Stelt een `MSMessage` samen met een gerenderde kaart van de
    /// handbagage-regel en voegt 'm direct in het gesprek in — de gebruiker
    /// hoeft alleen nog op versturen te tikken.
    private func sendBaggageCard(airline: Airline, variant: AirlineVariant) {
        guard let conversation = activeConversation else { return }

        let layout = MSMessageTemplateLayout()
        layout.image = BaggageRuleCard(airline: airline, variant: variant).snapshot()
        layout.caption = airline.name
        layout.subcaption = "Handbagage: \(variant.smallDimString)"

        let message = MSMessage()
        message.layout = layout
        message.summaryText = "Handbagagecheck: \(airline.name) — \(variant.smallDimString)"

        conversation.insert(message) { _ in }
        dismiss(animated: true)
    }

    /// Verstuurt een bestaande sticker als `MSSticker` — dezelfde afbeeldingen
    /// als de vroegere losse stickerpack-extensie, nu vanuit deze extensie.
    private func sendSticker(_ item: StickerItem) {
        guard let conversation = activeConversation,
              let url = Bundle.main.url(forResource: item.filename, withExtension: "png"),
              let sticker = try? MSSticker(contentsOfFileURL: url, localizedDescription: item.displayName)
        else { return }

        conversation.insert(sticker, completionHandler: nil)
        dismiss(animated: true)
    }
}

private extension View {
    @MainActor
    func snapshot() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}
