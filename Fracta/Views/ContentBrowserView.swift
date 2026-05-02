import SwiftUI
import WebKit

struct ContentBrowserView: View {
    let destination: String
    @State private var isInitialLoading = true
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ContentBrowserRepresentable(
                destination: destination,
                isInitialLoading: $isInitialLoading
            )
            .ignoresSafeArea()
            
            if isInitialLoading {
                Color.black
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .statusBarHidden(true)
    }
}

struct ContentBrowserRepresentable: UIViewControllerRepresentable {
    let destination: String
    @Binding var isInitialLoading: Bool
    
    func makeUIViewController(context: Context) -> ContentBrowserController {
        let controller = ContentBrowserController()
        controller.destination = destination
        controller.coordinator = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ContentBrowserController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isInitialLoading: $isInitialLoading)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isInitialLoading: Bool
        private var hasFinishedInitialLoad = false
        
        init(isInitialLoading: Binding<Bool>) {
            _isInitialLoading = isInitialLoading
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !hasFinishedInitialLoad {
                hasFinishedInitialLoad = true
                DispatchQueue.main.async {
                    self.isInitialLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if !hasFinishedInitialLoad {
                hasFinishedInitialLoad = true
                DispatchQueue.main.async {
                    self.isInitialLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}

class ContentBrowserController: UIViewController {
    var destination: String = ""
    var coordinator: ContentBrowserRepresentable.Coordinator?
    private var contentView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupContentView()
        loadDestination()
    }
    
    private func setupContentView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        
        contentView = WKWebView(frame: .zero, configuration: configuration)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.navigationDelegate = coordinator
        contentView.scrollView.contentInsetAdjustmentBehavior = .never
        contentView.allowsBackForwardNavigationGestures = true
        contentView.backgroundColor = .black
        contentView.isOpaque = false
        
        view.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func loadDestination() {
        guard let address = URL(string: destination) else { return }
        var request = URLRequest(url: address)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        contentView.load(request)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateOrientation()
    }
    
    private func updateOrientation() {
        setNeedsUpdateOfSupportedInterfaceOrientations()
        
        guard let windowScene = view.window?.windowScene else { return }
        
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .all)
        windowScene.requestGeometryUpdate(geometryPreferences) { _ in }
    }
}
