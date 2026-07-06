import SwiftUI
import AVKit

// MARK: - Productvideo-koppeling

/// Koppelt bekende producten aan een meegeleverde video. Nu alleen de
/// Amice-koffer; uitbreidbaar door meer merken/namen te matchen.
enum ProductMedia {
    /// Naam (zonder extensie) van een gebundelde video voor dit product, of nil.
    static func localVideoName(brand: String?, name: String) -> String? {
        let haystack = "\(brand ?? "") \(name)".lowercased()
        return haystack.contains("amice") ? "AmiceKoffer" : nil
    }

    /// URL van de gebundelde video, als die bestaat.
    static func localVideoURL(brand: String?, name: String) -> URL? {
        guard let base = localVideoName(brand: brand, name: name) else { return nil }
        return Bundle.main.url(forResource: base, withExtension: "mp4")
    }
}

extension Bag {
    var localVideoURL: URL? { ProductMedia.localVideoURL(brand: brand, name: name) }
}

extension BagDetail {
    var localVideoURL: URL? { ProductMedia.localVideoURL(brand: brand, name: name) }
}

// MARK: - Inline loopende preview (etalage)

/// Naadloos loopende, gedempte video voor een productpreview — speelt vanzelf
/// af zoals een reclamescherm, zonder bediening.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingPlayerUIView: UIView {
    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(url: URL) {
        super.init(frame: .zero)
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .advance
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspectFill
        queuePlayer.play()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func stop() {
        queuePlayer.pause()
        queuePlayer.removeAllItems()
    }
}

// MARK: - Volledige productgallerij (full-screen)

/// Full-screen gallerij: video (indien aanwezig) vooraan, daarna de foto's.
/// Foto's zijn in te zoomen; de video speelt met bediening en geluid.
struct ProductGalleryView: View {
    let imageUrls: [String]
    let videoURL: URL?
    var title: String? = nil
    @State var selection: Int
    @Environment(\.dismiss) private var dismiss

    /// Totaal aantal pagina's: eventueel de video + alle foto's.
    private var pageCount: Int { (videoURL != nil ? 1 : 0) + imageUrls.count }
    private var hasVideo: Bool { videoURL != nil }
    private var isVideoPage: Bool { hasVideo && selection == 0 }

    var body: some View {
        ZStack {
            // Zachte radiale achtergrond i.p.v. hard zwart — geeft diepte en
            // laat de productfoto's mooier "zweven".
            RadialGradient(
                colors: [Color(white: 0.16), Color.black],
                center: .center, startRadius: 40, endRadius: 600
            )
            .ignoresSafeArea()

            TabView(selection: $selection) {
                if let videoURL {
                    GalleryVideoPage(url: videoURL)
                        .tag(0)
                }
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { idx, url in
                    ZoomableImage(urlString: url)
                        .tag(hasVideo ? idx + 1 : idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Boven- en onderbalk zweven over de foto's.
            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(alignment: .center) {
            // Teller / titel links.
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(.frutiger(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if pageCount > 1 {
                    Text("\(selection + 1) / \(pageCount)")
                        .font(.frutiger(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(selection)))
                }
            }
            .animation(.snappy, value: selection)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Sluit gallerij")
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Hint: alleen bij foto's, subtiel.
            if !isVideoPage && !imageUrls.isEmpty {
                Label("Knijp of dubbeltik om in te zoomen", systemImage: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                    .font(.frutiger(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if pageCount > 1 {
                HStack(spacing: 7) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        let isVideoDot = hasVideo && i == 0
                        Group {
                            if isVideoDot {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 7, weight: .black))
                                    .foregroundStyle(i == selection ? .white : .white.opacity(0.4))
                                    .frame(width: 10, height: 10)
                            } else {
                                Capsule()
                                    .fill(i == selection ? Color.white : Color.white.opacity(0.35))
                                    .frame(width: i == selection ? 20 : 7, height: 7)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selection = i
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.3), value: selection)
            }
        }
        .padding(.bottom, 26)
    }
}

/// Videopagina in de gallerij: native speler met bediening en geluid.
private struct GalleryVideoPage: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                Color.clear
            }
        }
        .onAppear {
            let p = AVPlayer(url: url)
            p.play()
            player = p
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

/// Inzoombare foto: dubbeltik of knijp om te vergroten, sleep om te pannen.
/// Belangrijk: de sleep-om-te-pannen-gesture wordt alléén aangehecht als je
/// ingezoomd bent (scale > 1). Op 100% laten we de horizontale veeg door aan
/// de TabView, zodat je gewoon tussen de foto's kunt bladeren.
private struct ZoomableImage: View {
    let urlString: String
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        image
            .gesture(magnification)
            .onTapGesture(count: 2) { toggleZoom() }
    }

    @ViewBuilder
    private var image: some View {
        let base = AuthorisedImage(urlString: urlString)
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())

        if scale > 1 {
            base.gesture(pan)   // pannen alleen wanneer ingezoomd
        } else {
            base                // op 100%: TabView krijgt de veeg
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3)) {
                    if scale < 1.02 { scale = 1; resetPan() }
                }
                lastScale = scale
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if scale > 1 {
                scale = 1; lastScale = 1; resetPan()
            } else {
                scale = 2.5; lastScale = 2.5
            }
        }
    }

    private func resetPan() {
        offset = .zero
        lastOffset = .zero
    }
}
