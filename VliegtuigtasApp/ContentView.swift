import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                CheckFlowView()
            }
            .tabItem { Label("Checker", systemImage: "checkmark.shield.fill") }

            NavigationStack {
                AirlineListView()
            }
            .tabItem { Label("Maatschappijen", systemImage: "airplane") }

            NavigationStack {
                BagsShopView()
            }
            .tabItem { Label("Shop", systemImage: "bag.fill") }
        }
        .tint(Theme.navy)
    }
}
