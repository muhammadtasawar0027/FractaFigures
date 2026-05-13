import UIKit
import WebKit

final class ContentBrowserController: UIViewController {
    var destination: String = ""
    
    private var contentView: WKWebView!
    private var loadingOverlay: UIView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var navigationCoordinator: BrowserNavigationCoordinator!
    private var hasFinishedInitialLoad = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationCoordinator = BrowserNavigationCoordinator(controller: self)
        setupContentView()
        setupLoadingOverlay()
        loadDestination()
    }
    
    private func setupContentView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = AppConstants.webViewApplicationName
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        
        contentView = WKWebView(frame: .zero, configuration: configuration)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.navigationDelegate = navigationCoordinator
        contentView.uiDelegate = navigationCoordinator
        contentView.scrollView.contentInsetAdjustmentBehavior = .never
        contentView.allowsBackForwardNavigationGestures = true
        contentView.backgroundColor = .black
        contentView.isOpaque = false
        
        view.backgroundColor = .black
        view.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
    }
    
    private func setupLoadingOverlay() {
        loadingOverlay = UIView()
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = .black
        view.addSubview(loadingOverlay)
        
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    private func loadDestination() {
        guard let address = URL(string: destination) else {
            finishInitialLoading()
            return
        }
        navigationCoordinator.lastNavigatedURL = address
        var request = URLRequest(url: address)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        contentView.load(request)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.finishInitialLoading()
        }
    }
    
    func reload(url: URL) {
        contentView.load(URLRequest(url: url))
    }
    
    func finishInitialLoading() {
        guard !hasFinishedInitialLoad else { return }
        hasFinishedInitialLoad = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let overlay = self.loadingOverlay else { return }
            self.loadingIndicator.stopAnimating()
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.isHidden = true
            })
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        OrientationManager.shared.unlockAllOrientations()
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OrientationManager.shared.unlockAllOrientations()
        setNeedsUpdateOfSupportedInterfaceOrientations()
        UIViewController.attemptRotationToDeviceOrientation()
    }
}

final class BrowserNavigationCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var controller: ContentBrowserController?
    var lastNavigatedURL: URL?
    
    init(controller: ContentBrowserController) {
        self.controller = controller
    }
    
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        controller?.finishInitialLoading()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        controller?.finishInitialLoading()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorHTTPTooManyRedirects {
            let failingURL = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? lastNavigatedURL
            if let url = failingURL {
                webView.load(URLRequest(url: url))
                return
            }
        }
        controller?.finishInitialLoading()
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        controller?.finishInitialLoading()
        if let url = lastNavigatedURL {
            webView.load(URLRequest(url: url))
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            lastNavigatedURL = url
        }
        decisionHandler(.allow)
    }
}
