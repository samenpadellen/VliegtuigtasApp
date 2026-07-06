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
    @State var selection: Int
    @Environment(\.dismiss) private var dismiss

    /// Totaal aantal pagina's: eventueel de video + alle foto's.
    private var pageCount: Int { (videoURL != nil ? 1 : 0) + imageUrls.count }
    private var hasVideo: Bool { videoURL != nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Sluit gallerij")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if pageCount > 1 {
                    HStack(spacing: 7) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Circle()
                                .fill(i == selection ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.bottom, 28)
                    .animation(.spring(response: 0.3), value: selection)
                }
            }
        }
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
                Color.black
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
private struct ZoomableImage: View {
    let urlString: String
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            AuthorisedImage(urlString: urlString)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(lastScale * value, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1 { resetPan() }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1 else { return }
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in lastOffset = offset }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1 {
                            scale = 1; lastScale = 1; resetPan()
                        } else {
                            scale = 2.5; lastScale = 2.5
                        }
                    }
                }
        }
    }

    private func resetPan() {
        offset = .zero
        lastOffset = .zero
    }
}
