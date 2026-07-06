import SwiftUI
import RealityKit

/// Gedeelde staat tussen het hoofdvenster en het volumetrische venster.
@MainActor
final class VisionBagState: ObservableObject {
    static let shared = VisionBagState()

    /// Tasmaten in cm (hoogte, breedte, diepte).
    @Published var bagDims: (h: Double, w: Double, d: Double) = (55, 40, 20)
    /// Limiet van de gekozen maatschappij in cm, indien bekend.
    @Published var limitDims: (h: Double, w: Double, d: Double)?
    @Published var airlineName: String?

    var fits: Bool? {
        guard let limit = limitDims else { return nil }
        let bag = [bagDims.h, bagDims.w, bagDims.d].sorted(by: >)
        let lim = [limit.h, limit.w, limit.d].sorted(by: >)
        return bag[0] <= lim[0] && bag[1] <= lim[1] && bag[2] <= lim[2]
    }

    private init() {}
}

/// Je koffer op ware grootte, zwevend in je kamer. Geel volume = jouw tas;
/// transparante kooi = wat de maatschappij toestaat. In één oogopslag zie
/// je — levensecht — of en wáár hij te groot is.
struct BagVolumeView: View {
    @EnvironmentObject private var state: VisionBagState

    var body: some View {
        RealityView { content in
            rebuild(content: &content)
        } update: { content in
            rebuild(content: &content)
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            legend
        }
    }

    private func rebuild(content: inout RealityViewContent) {
        content.entities.removeAll()

        let root = Entity()

        // Jouw tas: geel, ware grootte (cm → meter)
        let bagSize = SIMD3<Float>(
            Float(state.bagDims.w / 100),
            Float(state.bagDims.h / 100),
            Float(state.bagDims.d / 100)
        )
        let bag = ModelEntity(
            mesh: .generateBox(size: bagSize, cornerRadius: 0.015),
            materials: [SimpleMaterial(
                color: UIColor(red: 0.99, green: 0.80, blue: 0.10, alpha: 1),
                roughness: 0.55, isMetallic: false
            )]
        )
        bag.position = [0, bagSize.y / 2, 0]
        root.addChild(bag)

        // Limietkooi van de maatschappij: doorschijnend, groen of rood
        if let limit = state.limitDims {
            let cageSize = SIMD3<Float>(
                Float(limit.w / 100),
                Float(limit.h / 100),
                Float(limit.d / 100)
            )
            let fits = state.fits ?? true
            let cageColor = fits
                ? UIColor(red: 0.18, green: 0.73, blue: 0.45, alpha: 0.28)
                : UIColor(red: 0.90, green: 0.25, blue: 0.25, alpha: 0.28)
            let cage = ModelEntity(
                mesh: .generateBox(size: cageSize, cornerRadius: 0.004),
                materials: [SimpleMaterial(color: cageColor, roughness: 0.2, isMetallic: false)]
            )
            cage.position = [0, cageSize.y / 2, 0]
            root.addChild(cage)
        }

        // Vloerplaat: subtiel platform zodat de koffer ergens "staat"
        let floor = ModelEntity(
            mesh: .generateCylinder(height: 0.005, radius: max(bagSize.x, bagSize.z) * 0.85 + 0.06),
            materials: [SimpleMaterial(
                color: UIColor(red: 0.00, green: 0.12, blue: 0.38, alpha: 0.35),
                roughness: 0.8, isMetallic: false
            )]
        )
        floor.position = [0, -0.0025, 0]
        root.addChild(floor)

        // Onderin het volume plaatsen
        root.position = [0, -0.45, 0]
        content.add(root)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Label {
                Text("\(Int(state.bagDims.h)) × \(Int(state.bagDims.w)) × \(Int(state.bagDims.d)) cm")
                    .monospacedDigit()
            } icon: {
                Circle()
                    .fill(Color(red: 0.99, green: 0.80, blue: 0.10))
                    .frame(width: 10, height: 10)
            }

            if let limit = state.limitDims {
                Divider().frame(height: 16)
                Label {
                    Text("Limiet\(state.airlineName.map { " \($0)" } ?? ""): \(Int(limit.h)) × \(Int(limit.w)) × \(Int(limit.d)) cm")
                        .monospacedDigit()
                } icon: {
                    Circle()
                        .fill((state.fits ?? true) ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .font(.frutiger(size: 15, weight: .medium))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassBackgroundEffect()
    }
}
