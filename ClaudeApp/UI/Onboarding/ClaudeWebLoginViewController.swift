import UIKit
import WebKit

final class ClaudeWebLoginViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        return WKWebView(frame: .zero, configuration: config)
    }()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let hintLabel = UILabel()

    private var timer: Timer?
    private var isProcessingLogin = false
    private let completion: (Bool, String?) -> Void

    private var isObservingProgress = false

    init(completion: @escaping (Bool, String?) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
        timer = nil
        if isObservingProgress {
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            isObservingProgress = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "claude.ai にログイン"
        view.backgroundColor = .white

        // Navigation items
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadTapped))

        // Progress
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        view.addSubview(progressView)

        // WebView
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Hint label
        hintLabel.text = "メールアドレスでログインしてください。Google ログインはアプリ内ブラウザでは利用できない場合があります。\nメールに届いたコードを入力してください"
        hintLabel.font = UIFont.systemFont(ofSize: 12)
        hintLabel.textColor = .darkGray
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -8),

            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        // KVO progress
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        isObservingProgress = true

        // Load login
        if let url = URL(string: "https://claude.ai/login") {
            webView.load(URLRequest(url: url))
        }

        // Timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForSessionCookie()
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            let progress = Float(webView.estimatedProgress)
            progressView.progress = progress
            progressView.isHidden = progress >= 1.0
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    @objc private func cancelTapped() {
        timer?.invalidate()
        timer = nil
        dismiss(animated: true) { [weak self] in
            self?.completion(false, ClaudeAccountAuthError.cancelled.errorDescription)
        }
    }

    @objc private func reloadTapped() {
        webView.reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkForSessionCookie()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https" {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let request = navigationAction.request as URLRequest? {
            webView.load(request)
        } else if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    // MARK: - Cookie detection

    private func checkForSessionCookie() {
        guard !isProcessingLogin else { return }
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            guard !self.isProcessingLogin else { return }
            var sessionKeyValue: String?
            var orgValue: String?
            for cookie in cookies {
                let domain = cookie.domain.lowercased()
                guard domain.hasSuffix("claude.ai") else { continue }
                if cookie.name == "sessionKey" {
                    sessionKeyValue = cookie.value
                }
                if cookie.name == "lastActiveOrg" {
                    orgValue = cookie.value
                }
            }
            guard let sk = sessionKeyValue, !sk.isEmpty else { return }
            self.isProcessingLogin = true
            ClaudeAccountAuth.shared.storeSession(sessionKey: sk, lastActiveOrg: orgValue)
            ClaudeAccountAuth.shared.validate { [weak self] success, message in
                guard let self = self else { return }
                if success {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.dismiss(animated: true) { [weak self] in
                        self?.completion(true, nil)
                    }
                } else {
                    self.isProcessingLogin = false
                    let alert = UIAlertController(title: nil, message: message ?? "ログインに失敗しました。", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
