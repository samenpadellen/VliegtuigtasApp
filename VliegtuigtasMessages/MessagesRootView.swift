import SwiftUI

/// De ene extensie doet nu twee dingen — bagagecheck en stickers — met een
/// segmented control erboven om te wisselen. Eén `NavigationStack` hier,
/// gedeeld door beide tabs.
struct MessagesRootView: View {
    private enum Tab { case baggage, stickers }
    @State private var tab: Tab = .baggage

    let onSendBaggage: (Airline, AirlineVariant) -> Void
    let onSendSticker: (StickerItem) -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .baggage:  QuickBaggageCheckView(onSend: onSendBaggage)
                case .stickers: StickerPickerView(onSend: onSendSticker)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $tab) {
                        Text("Bagagecheck").tag(Tab.baggage)
                        Text("Stickers").tag(Tab.stickers)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
    }
}
