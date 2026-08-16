import SwiftUI

// ARKit bestaat niet op Mac Catalyst; de scanner is een iPhone/iPad-feature.
#if !targetEnvironment(macCatalyst)
import ARKit
import SceneKit

/// De AR-tasmeting vereist LiDAR: alleen dan is er een scene-mesh om de tas
/// écht mee op te meten. Zonder LiDAR verbergen we de feature en melden we
/// dat bij de functies in het profiel.
enum LiDARSupport {
    static var isAvailable: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
}

// MARK: - Meetmodel

/// Geen @MainActor-annotatie bewust: de zware meshverwerking draait op een
/// achtergrondqueue (zie Coordinator), en publiceert resultaten expliciet
/// via DispatchQueue.main. Alle andere aanroepen (UIKit-gestures, SwiftUI-
/// knoppen) gebeuren toch al op main.
final class BagScanModel: ObservableObject {
    enum Phase {
        case position   // tik om het scanvolume te plaatsen
        case scanning   // LiDAR-mesh wordt live tot een boundingbox gefit
        case done
    }

    /// Minimaal aantal unieke, op 1 cm gerasterde meshpunten voordat een
    /// meting betrouwbaar genoeg is om af te ronden.
    static let minPointsToFinish = 220

    @Published var phase: Phase = .position
    @Published var lidarActive = false
    @Published var tapFeedback: TapFeedback?

    /// Vloerpunt + afmetingen (breedte x, hoogte y, diepte z in meter) van
    /// het instelbare scanvolume: alleen meshpunten hierbinnen tellen mee.
    @Published var volumeCenter: simd_float3?
    @Published var floorY: Float?
    @Published var volumeSize = simd_float3(0.70, 0.55, 0.50)

    /// Live bijgewerkt tijdens het scannen.
    @Published var pointCount = 0
    @Published var liveLengthCm: Double?
    @Published var liveWidthCm: Double?
    @Published var liveHeightCm: Double?

    /// Definitief na "Klaar".
    @Published var lengthCm: Double?
    @Published var widthCm: Double?
    @Published var heightCm: Double?

    /// Toegestane maten (h, b, d in cm) van de gekozen maatschappij — in AR
    /// getoond als kooi om de tas, met direct oordeel.
    var limitsCm: (h: Double, w: Double, d: Double)?
    var airlineName: String?

    struct TapFeedback: Identifiable, Equatable {
        let id = UUID()
        let location: CGPoint
        let success: Bool
        let text: String
    }

    var isComplete: Bool { phase == .done }
    var canFinish: Bool { pointCount >= Self.minPointsToFinish }

    var accuracyLabel: String {
        switch pointCount {
        case ..<Self.minPointsToFinish: return "Blijf scannen voor een betrouwbare meting"
        case Self.minPointsToFinish..<1200: return "Redelijke nauwkeurigheid"
        default: return "Hoge nauwkeurigheid"
        }
    }

    /// Oordeel t.o.v. de limiet, oriëntatie-onafhankelijk. nil = geen limiet bekend.
    var fitsLimits: Bool? {
        guard let limits = limitsCm,
              let h = heightCm, let l = lengthCm, let w = widthCm else { return nil }
        let bag = [h, l, w].sorted(by: >)
        let lim = [limits.h, limits.w, limits.d].sorted(by: >)
        return bag[0] <= lim[0] && bag[1] <= lim[1] && bag[2] <= lim[2]
    }

    func placeVolume(at point: simd_float3) {
        volumeCenter = point
        floorY = point.y
    }

    func resizeVolume(dx: Float = 0, dy: Float = 0, dz: Float = 0) {
        volumeSize.x = min(1.1, max(0.25, volumeSize.x + dx))
        volumeSize.y = min(1.0, max(0.20, volumeSize.y + dy))
        volumeSize.z = min(1.1, max(0.25, volumeSize.z + dz))
    }

    func startScanning() {
        guard volumeCenter != nil else { return }
        pointCount = 0
        liveLengthCm = nil; liveWidthCm = nil; liveHeightCm = nil
        phase = .scanning
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func updateLive(lengthCm: Double, widthCm: Double, heightCm: Double, pointCount: Int) {
        liveLengthCm = lengthCm
        liveWidthCm = widthCm
        liveHeightCm = heightCm
        self.pointCount = pointCount
    }

    func finish() {
        guard canFinish, let l = liveLengthCm, let w = liveWidthCm, let h = liveHeightCm else { return }
        lengthCm = l
        widthCm = w
        heightCm = h
        phase = .done
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func reset() {
        phase = .position
        volumeCenter = nil
        floorY = nil
        pointCount = 0
        liveLengthCm = nil; liveWidthCm = nil; liveHeightCm = nil
        lengthCm = nil; widthCm = nil; heightCm = nil
    }

    func registerMiss(at location: CGPoint) {
        show(TapFeedback(location: location, success: false, text: "Geen vloer gevonden, richt lager"))
    }

    func registerPlacement(at location: CGPoint) {
        show(TapFeedback(location: location, success: true, text: "Scanvolume geplaatst"))
    }

    private func show(_ feedback: TapFeedback) {
        tapFeedback = feedback
        let id = feedback.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.tapFeedback?.id == id { self?.tapFeedback = nil }
        }
    }
}

// MARK: - Geometrie: beste-passende rechthoek door een puntenwolk

/// Geeft de (min,max) van een reeks terug, met de buitenste ~1% aan elke
/// kant weggesneden. Een enkel ruispunt — een kortstondig mesh-artefact, een
/// vinger net binnen het scanvolume — mag de hele meting niet laten
/// uitschieten: `orientedFloorBox` en de hoogtemeting gebruikten voorheen de
/// werkelijke extremen, waardoor één uitschieter de tas blijvend te groot
/// liet meten (het rasterpuntenwolk groeit alleen maar tijdens het scannen,
/// dus die uitschieter verdween nooit meer). Bij weinig punten is er te
/// weinig om veilig te trimmen; dan valt dit terug op de echte extremen.
private func trimmedExtent(_ values: [Float], trimFraction: Float = 0.01) -> (min: Float, max: Float) {
    let sorted = values.sorted()
    let trim = min(sorted.count / 3, Int(Float(sorted.count) * trimFraction))
    return (sorted[trim], sorted[sorted.count - 1 - trim])
}

/// Georiënteerde boundingbox van een puntenwolk in het platte (x,z) vlak,
/// via hoofdcomponentenanalyse (PCA): de richting van de grootste variantie
/// is de lange as van de tas, ongeacht hoe de tas t.o.v. de camera staat.
/// Dit vervangt het handmatig aantikken van hoeken door een écht op de
/// gescande meshgeometrie gebaseerde meting.
private func orientedFloorBox(of points: [SIMD2<Float>]) -> (center: SIMD2<Float>, sizeAlongAxis: Float, sizeAlongPerp: Float, axisAngle: Float)? {
    guard points.count >= 8 else { return nil }
    let n = Float(points.count)
    let meanX = points.reduce(Float(0)) { $0 + $1.x } / n
    let meanZ = points.reduce(Float(0)) { $0 + $1.y } / n

    var sxx: Float = 0, szz: Float = 0, sxz: Float = 0
    for p in points {
        let dx = p.x - meanX, dz = p.y - meanZ
        sxx += dx * dx
        szz += dz * dz
        sxz += dx * dz
    }
    sxx /= n; szz /= n; sxz /= n

    // Grootste eigenwaarde/-vector van de 2×2-covariantiematrix, in gesloten
    // vorm (geen matrixbibliotheek nodig voor een 2×2-symmetrische matrix).
    let trace = sxx + szz
    let det = sxx * szz - sxz * sxz
    let discriminant = max(0, (trace * trace) / 4 - det)
    let lambda1 = trace / 2 + sqrt(discriminant)

    var axis = SIMD2<Float>(1, 0)
    if abs(sxz) > 1e-8 {
        axis = simd_normalize(SIMD2<Float>(lambda1 - szz, sxz))
    } else if szz > sxx {
        axis = SIMD2<Float>(0, 1)
    }
    let angle = atan2(axis.y, axis.x)
    let cosT = cos(angle), sinT = sin(angle)

    // Alle punten uitdrukken in het door PCA gevonden assenstelsel en de
    // extent per as opmeten — dat geeft de strakst passende rechthoek.
    // Getrimd (zie trimmedExtent) i.p.v. de kale min/max, zodat één
    // uitschieter de tas niet blijvend te groot laat meten.
    var us: [Float] = []; us.reserveCapacity(points.count)
    var vs: [Float] = []; vs.reserveCapacity(points.count)
    for p in points {
        let dx = p.x - meanX, dz = p.y - meanZ
        us.append(dx * cosT + dz * sinT)
        vs.append(-dx * sinT + dz * cosT)
    }
    let (minU, maxU) = trimmedExtent(us)
    let (minV, maxV) = trimmedExtent(vs)

    let centerU = (minU + maxU) / 2
    let centerV = (minV + maxV) / 2
    let centerX = meanX + centerU * cosT - centerV * sinT
    let centerZ = meanZ + centerU * sinT + centerV * cosT

    return (
        center: SIMD2<Float>(centerX, centerZ),
        sizeAlongAxis: maxU - minU,
        sizeAlongPerp: maxV - minV,
        axisAngle: angle
    )
}

// MARK: - AR-container

private struct ARMeasureContainer: UIViewRepresentable {
    let model: BagScanModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.session.delegate = context.coordinator
        context.coordinator.view = view

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            DispatchQueue.main.async { model.lidarActive = true }
        }
        view.session.run(config)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.captureSize = model.volumeSize

        switch model.phase {
        case .position:
            if let center = model.volumeCenter, let floorY = model.floorY {
                coordinator.showVolume(center: center, floorY: floorY, size: model.volumeSize, in: view)
            } else {
                coordinator.resetSceneIfNeeded(in: view)
            }
            coordinator.stopScanning()
        case .scanning:
            coordinator.beginScanningIfNeeded(center: model.volumeCenter, floorY: model.floorY, size: model.volumeSize, in: view)
            // Live boundingbox wordt bijgewerkt vanuit de ARSessionDelegate-
            // callback zelf, niet vanuit deze SwiftUI-cyclus.
        case .done:
            coordinator.freezeIfNeeded(limits: model.limitsCm, fits: model.fitsLimits, in: view)
        }
    }

    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) {
        view.session.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    /// Verwerkt tikken (plaatsing) op main thread, en LiDAR-meshframes op een
    /// eigen achtergrondqueue: het doorlopen van duizenden meshvertices per
    /// update mag de UI nooit blokkeren. Alleen `gridPoints` wordt vanuit
    /// twee kanten aangeraakt (scan-callback én reset/start-knoppen), en is
    /// daarom met een lock beveiligd; alle SceneKit- en model-mutaties gaan
    /// expliciet terug via de main queue.
    final class Coordinator: NSObject, ARSessionDelegate {
        let model: BagScanModel
        weak var view: ARSCNView?

        private var volumeNode: SCNNode?
        private var liveBoxNode: SCNNode?
        private var cageNode: SCNNode?

        private let gridLock = NSLock()
        private var gridPoints: Set<SIMD3<Int32>> = []

        private var captureCenter: simd_float3?
        private var captureFloorY: Float?
        var captureSize = simd_float3(0.70, 0.55, 0.50)
        private var isScanning = false
        private var lastProcessTime: TimeInterval = 0
        private let processInterval: TimeInterval = 0.25
        /// Elke 3e vertex bemonsteren is ruim genoeg voor een boundingbox-fit
        /// en scheelt fors in rekentijd bij een dichte LiDAR-mesh.
        private let vertexStride = 3

        init(model: BagScanModel) {
            self.model = model
            super.init()
        }

        // MARK: Tikken: scanvolume plaatsen (altijd main thread, UIKit-gesture)

        @objc func onTap(_ gesture: UITapGestureRecognizer) {
            guard let view, model.phase == .position else { return }
            let location = gesture.location(in: view)
            guard let query = view.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal),
                  let hit = view.session.raycast(query).first else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                model.registerMiss(at: location)
                return
            }
            let t = hit.worldTransform.columns.3
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            model.placeVolume(at: simd_float3(t.x, t.y, t.z))
            model.registerPlacement(at: location)
        }

        // MARK: Scanvolume (wireframe) tonen tijdens het positioneren

        func showVolume(center: simd_float3, floorY: Float, size: simd_float3, in view: ARSCNView) {
            let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0.01)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(red: 0.99, green: 0.80, blue: 0.10, alpha: 1)
            material.fillMode = .lines
            material.isDoubleSided = true
            box.firstMaterial = material

            if let node = volumeNode {
                node.geometry = box
            } else {
                let node = SCNNode(geometry: box)
                view.scene.rootNode.addChildNode(node)
                volumeNode = node
            }
            volumeNode?.position = SCNVector3(center.x, floorY + size.y / 2, center.z)
        }

        func resetSceneIfNeeded(in view: ARSCNView) {
            guard volumeNode != nil || liveBoxNode != nil || cageNode != nil else { return }
            view.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            volumeNode = nil
            liveBoxNode = nil
            cageNode = nil
            gridLock.lock(); gridPoints.removeAll(); gridLock.unlock()
            lastProcessTime = 0
            captureCenter = nil
            captureFloorY = nil
        }

        func stopScanning() {
            isScanning = false
        }

        // MARK: Scanfase starten

        func beginScanningIfNeeded(center: simd_float3?, floorY: Float?, size: simd_float3, in view: ARSCNView) {
            guard !isScanning, let center, let floorY else { return }
            volumeNode?.removeFromParentNode()
            volumeNode = nil
            captureCenter = center
            captureFloorY = floorY
            captureSize = size
            gridLock.lock(); gridPoints.removeAll(); gridLock.unlock()
            lastProcessTime = 0
            isScanning = true
        }

        // MARK: LiDAR-meshframes verwerken (achtergrondqueue van ARKit)

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard isScanning, let center = captureCenter, let floorY = captureFloorY else { return }
            let now = frame.timestamp
            guard now - lastProcessTime >= processInterval else { return }
            lastProcessTime = now

            let size = captureSize
            let halfW = size.x / 2
            let halfD = size.z / 2
            let minY = floorY + 0.015   // 1,5 cm boven vloer: negeert vloerruis
            let maxY = floorY + size.y
            let anchors = frame.anchors
            let stride = vertexStride

            gridLock.lock()
            var localGrid = gridPoints
            gridLock.unlock()

            for anchor in anchors {
                guard let mesh = anchor as? ARMeshAnchor else { continue }
                let source = mesh.geometry.vertices
                let count = source.count
                guard count > 0 else { continue }
                let vertexStrideBytes = source.stride
                let offset = source.offset
                let transform = mesh.transform
                let bufferPointer = source.buffer.contents()

                var i = 0
                while i < count {
                    let vertexPointer = bufferPointer
                        .advanced(by: offset + vertexStrideBytes * i)
                        .assumingMemoryBound(to: SIMD3<Float>.self)
                    let local = vertexPointer.pointee
                    let world4 = transform * SIMD4<Float>(local.x, local.y, local.z, 1)

                    if world4.y > minY, world4.y < maxY,
                       abs(world4.x - center.x) < halfW,
                       abs(world4.z - center.z) < halfD {
                        let key = SIMD3<Int32>(
                            Int32((world4.x * 100).rounded()),
                            Int32((world4.y * 100).rounded()),
                            Int32((world4.z * 100).rounded())
                        )
                        localGrid.insert(key)
                    }
                    i += stride
                }
            }

            gridLock.lock()
            gridPoints = localGrid
            gridLock.unlock()

            guard localGrid.count >= 8 else {
                let count = localGrid.count
                DispatchQueue.main.async { [weak self] in
                    self?.model.updateLive(lengthCm: 0, widthCm: 0, heightCm: 0, pointCount: count)
                }
                return
            }

            let pointsXZ = localGrid.map { SIMD2<Float>(Float($0.x) / 100, Float($0.z) / 100) }
            // Getrimde max i.p.v. de kale max: hetzelfde uitschieter-probleem
            // als bij de lengte/breedte, en de rasterpuntenwolk groeit alleen
            // maar tijdens het scannen — één ruispunt in frame 3 van 40 zou
            // de hoogte anders voor de rest van de scan laten uitschieten.
            let maxYcm = trimmedExtent(localGrid.map { Float($0.y) }).max
            let heightM = max(0, maxYcm / 100 - floorY)
            guard let box = orientedFloorBox(of: pointsXZ) else { return }

            let lengthCm = Double(box.sizeAlongAxis) * 100
            let widthCm  = Double(box.sizeAlongPerp) * 100
            let heightCm = Double(heightM) * 100
            let count = localGrid.count

            DispatchQueue.main.async { [weak self] in
                guard let self, let view = self.view else { return }
                self.model.updateLive(lengthCm: lengthCm, widthCm: widthCm, heightCm: heightCm, pointCount: count)
                self.updateLiveBoxNode(box: box, floorY: floorY, heightM: heightM, in: view)
            }
        }

        private func updateLiveBoxNode(
            box: (center: SIMD2<Float>, sizeAlongAxis: Float, sizeAlongPerp: Float, axisAngle: Float),
            floorY: Float, heightM: Float, in view: ARSCNView
        ) {
            let h = max(0.02, heightM)
            let geo = SCNBox(
                width: CGFloat(max(0.02, box.sizeAlongAxis)),
                height: CGFloat(h),
                length: CGFloat(max(0.02, box.sizeAlongPerp)),
                chamferRadius: 0.005
            )
            geo.firstMaterial?.diffuse.contents = UIColor(red: 0.00, green: 0.63, blue: 0.87, alpha: 0.32)
            geo.firstMaterial?.isDoubleSided = true

            if let node = liveBoxNode {
                node.geometry = geo
            } else {
                let node = SCNNode(geometry: geo)
                view.scene.rootNode.addChildNode(node)
                liveBoxNode = node
            }
            liveBoxNode?.position = SCNVector3(box.center.x, floorY + h / 2, box.center.y)
            liveBoxNode?.eulerAngles.y = -box.axisAngle
        }

        // MARK: Afronden: bevriest de laatste live box en tekent de limietkooi

        func freezeIfNeeded(limits: (h: Double, w: Double, d: Double)?, fits: Bool?, in view: ARSCNView) {
            isScanning = false
            guard cageNode == nil, let limits, let boxNode = liveBoxNode else { return }

            let fitsValue = fits ?? true
            let cage = SCNBox(
                width: CGFloat(max(limits.w, limits.d) / 100),
                height: CGFloat(limits.h / 100),
                length: CGFloat(min(limits.w, limits.d) / 100),
                chamferRadius: 0
            )
            let material = SCNMaterial()
            material.diffuse.contents = fitsValue
                ? UIColor(red: 0.18, green: 0.73, blue: 0.45, alpha: 1)
                : UIColor(red: 0.90, green: 0.25, blue: 0.25, alpha: 1)
            material.fillMode = .lines
            material.isDoubleSided = true
            cage.firstMaterial = material

            let node = SCNNode(geometry: cage)
            node.position = boxNode.position
            node.eulerAngles = boxNode.eulerAngles
            node.opacity = 0.9
            view.scene.rootNode.addChildNode(node)
            cageNode = node
        }
    }
}

// MARK: - Tik-feedback (ring + label op het tikpunt)

private struct TapFeedbackView: View {
    let feedback: BagScanModel.TapFeedback
    @State private var expanded = false

    private var color: Color { feedback.success ? Theme.green : Theme.red }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: expanded ? 1.5 : 4)
                .frame(width: 54, height: 54)
                .scaleEffect(expanded ? 1.7 : 0.3)
                .opacity(expanded ? 0 : 0.9)

            Image(systemName: feedback.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
                .scaleEffect(expanded ? 1 : 0.4)
                .opacity(expanded ? 1 : 0)

            if !feedback.text.isEmpty {
                Text(feedback.text)
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(color.opacity(0.85))
                    .clipShape(Capsule())
                    .fixedSize()
                    .offset(y: -44)
                    .opacity(expanded ? 1 : 0)
                    .scaleEffect(expanded ? 1 : 0.8, anchor: .bottom)
            }
        }
        .position(feedback.location)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                expanded = true
            }
        }
    }
}

// MARK: - Scanner-scherm

struct BagScannerView: View {
    /// Maatschappij + toegestane maten (h, b, d in cm) voor de AR-limietkooi.
    var airlineName: String? = nil
    var limitsCm: (h: Double, w: Double, d: Double)? = nil
    /// (hoogte, breedte, diepte) in cm — in de volgorde van de checker-sliders.
    let onMeasured: (Double, Double, Double) -> Void

    @StateObject private var model = BagScanModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if ARWorldTrackingConfiguration.isSupported {
                ARMeasureContainer(model: model)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textSecondary)
                    Text("AR wordt niet ondersteund op dit toestel.")
                        .font(.frutiger(size: 15))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }

            if let feedback = model.tapFeedback {
                TapFeedbackView(feedback: feedback)
                    .id(feedback.id)
                    .allowsHitTesting(false)
            }

            VStack {
                topBar
                Spacer()
                bottomPanel
            }
        }
        .onAppear {
            model.limitsCm = limitsCm
            model.airlineName = airlineName
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45))
                    .clipShape(Circle())
            }
            Spacer()
            if model.lidarActive {
                HStack(spacing: 5) {
                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("LiDAR actief")
                        .font(.frutiger(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(.black.opacity(0.45))
                .clipShape(Capsule())
            }
        }
        .padding(Theme.Spacing.base)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        switch model.phase {
        case .position:  positionPanel
        case .scanning:  scanningPanel
        case .done:      resultPanel
        }
    }

    // MARK: Stap 1 — scanvolume plaatsen

    private var positionPanel: some View {
        VStack(spacing: 14) {
            if model.volumeCenter == nil {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.yellow)
                Text("Tik op de vloer vlak naast je tas")
                    .font(.frutiger(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Zorg voor goed licht. Het gele kader verschijnt op de plek waar je tikt.")
                    .font(.frutiger(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            } else {
                Text("Pas het gele kader aan tot je tas er helemaal in past")
                    .font(.frutiger(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 18) {
                    volumeStepper(icon: "arrow.left.and.right", label: "Breedte") {
                        model.resizeVolume(dx: $0 * 0.05)
                    }
                    volumeStepper(icon: "arrow.up.and.down", label: "Hoogte") {
                        model.resizeVolume(dy: $0 * 0.05)
                    }
                    volumeStepper(icon: "arrow.up.left.and.arrow.down.right", label: "Diepte") {
                        model.resizeVolume(dz: $0 * 0.05)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        model.reset()
                    } label: {
                        Text("Opnieuw tikken")
                            .font(.frutiger(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Theme.Spacing.base)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    Button {
                        model.startScanning()
                    } label: {
                        Label("Start scannen", systemImage: "viewfinder")
                            .font(.frutiger(size: 14, weight: .bold))
                            .foregroundStyle(Theme.navy)
                            .padding(.horizontal, Theme.Spacing.base)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(Theme.yellow)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, Theme.Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.base)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .padding(Theme.Spacing.base)
    }

    private func volumeStepper(icon: String, label: String, adjust: @escaping (Float) -> Void) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.frutiger(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 10) {
                Button { adjust(-1) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                }
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.yellow)
                Button { adjust(1) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: Stap 2 — live scannen

    private var scanningPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.sky)
                    .frame(width: 7, height: 7)
                    .opacity(model.pointCount > 0 ? 1 : 0.3)
                Text("Loop om je tas heen en bekijk 'm van alle kanten")
                    .font(.frutiger(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            if let l = model.liveLengthCm, let w = model.liveWidthCm, let h = model.liveHeightCm, model.pointCount > 0 {
                let breedte = max(l, w), diepte = min(l, w)
                Text("\(Int(h)) × \(Int(breedte)) × \(Int(diepte)) cm")
                    .font(.frutiger(size: 26, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.3), value: h + breedte + diepte)
            } else {
                Text("— × — × — cm")
                    .font(.frutiger(size: 26, weight: .black))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text(model.accuracyLabel)
                .font(.frutiger(size: 11, weight: .medium))
                .foregroundStyle(model.canFinish ? Theme.green : .white.opacity(0.6))

            Button {
                model.finish()
            } label: {
                Label("Klaar", systemImage: "checkmark")
                    .font(.frutiger(size: 15, weight: .bold))
                    .foregroundStyle(model.canFinish ? Theme.navy : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(model.canFinish ? Theme.yellow : Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .disabled(!model.canFinish)
            .padding(.top, Theme.Spacing.xs)

            Button {
                model.reset()
            } label: {
                Text("Opnieuw beginnen")
                    .font(.frutiger(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.base)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .padding(Theme.Spacing.base)
    }

    // MARK: Stap 3 — resultaat

    private var resultPanel: some View {
        Group {
            if let h = model.heightCm, let l = model.lengthCm, let w = model.widthCm {
                let breedte = max(l, w)
                let diepte = min(l, w)

                VStack(spacing: 10) {
                    Text("Gemeten met LiDAR")
                        .font(.frutiger(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(Int(h)) × \(Int(breedte)) × \(Int(diepte)) cm")
                        .font(.frutiger(size: 30, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("hoogte × breedte × diepte · \(model.accuracyLabel.lowercased())")
                        .font(.frutiger(size: 11))
                        .foregroundStyle(.white.opacity(0.6))

                    if let fits = model.fitsLimits, let name = model.airlineName {
                        HStack(spacing: 6) {
                            Image(systemName: fits ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(fits ? "Binnen de limiet van \(name)" : "Groter dan de limiet van \(name)")
                                .font(.frutiger(size: 12, weight: .bold))
                        }
                        .foregroundStyle(fits ? Theme.green : Theme.red)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background((fits ? Theme.green : Theme.red).opacity(0.15))
                        .clipShape(Capsule())
                    }

                    HStack(spacing: 10) {
                        Button {
                            model.reset()
                        } label: {
                            Label("Opnieuw", systemImage: "arrow.counterclockwise")
                                .font(.frutiger(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, Theme.Spacing.base)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onMeasured(h, breedte, diepte)
                            dismiss()
                        } label: {
                            Label("Gebruik maten", systemImage: "checkmark")
                                .font(.frutiger(size: 14, weight: .bold))
                                .foregroundStyle(Theme.navy)
                                .padding(.horizontal, Theme.Spacing.base)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.yellow)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, Theme.Spacing.xxs)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.base)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .padding(Theme.Spacing.base)
            }
        }
    }
}

#endif

#if targetEnvironment(macCatalyst)
/// Geen ARKit op de Mac: feature bestaat daar niet.
enum LiDARSupport {
    static let isAvailable = false
}
#endif
