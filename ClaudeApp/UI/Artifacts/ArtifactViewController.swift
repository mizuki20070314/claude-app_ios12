import UIKit
import WebKit

final class ArtifactViewController: UIViewController {

    private let titleText: String
    private let language: String?
    private let code: String

    private let segmentedControl = UISegmentedControl()
    private let containerView = UIView()

    private var previewView: UIView?
    private var codeTextView: UITextView?

    private let previewableLanguages: Set<String> = ["html", "svg", "markdown", "md"]

    init(title: String, language: String?, code: String) {
        self.titleText = title
        self.language = language
        self.code = code
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.titleText = ""
        self.language = nil
        self.code = ""
        super.init(coder: coder)
    }

    private var isPreviewable: Bool {
        let lang = (language ?? "").lowercased()
        return previewableLanguages.contains(lang)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = titleText
        applyTheme()
        setupNavButtons()
        setupSegmented()
        setupContainer()
        buildViews()
        showCodeOrPreview(initial: true)

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Theme.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.current.background
    }

    private func setupNavButtons() {
        let copy = UIBarButtonItem(title: NSLocalizedString("artifacts.copy", tableName: "Artifacts", comment: ""), style: .plain, target: self, action: #selector(copyTapped))
        let share = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareTapped))
        navigationItem.rightBarButtonItems = [share, copy]
    }

    private func setupSegmented() {
        if isPreviewable {
            segmentedControl.insertSegment(withTitle: NSLocalizedString("artifacts.preview", tableName: "Artifacts", comment: ""), at: 0, animated: false)
            segmentedControl.insertSegment(withTitle: NSLocalizedString("artifacts.code", tableName: "Artifacts", comment: ""), at: 1, animated: false)
            segmentedControl.selectedSegmentIndex = 0
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
            view.addSubview(segmentedControl)
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
                segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
        } else {
            segmentedControl.isHidden = true
        }
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        var topAnchor = view.safeAreaLayoutGuide.topAnchor
        if isPreviewable {
            topAnchor = segmentedControl.bottomAnchor
        }
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func buildViews() {
        let lang = (language ?? "").lowercased()
        if isPreviewable {
            if lang == "html" {
                let webView = WKWebView(frame: .zero)
                webView.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(webView)
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
                previewView = webView
                let html = code
                webView.loadHTMLString(html, baseURL: nil)
            } else if lang == "svg" {
                let webView = WKWebView(frame: .zero)
                webView.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(webView)
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
                previewView = webView
                let wrapped = """
                <!DOCTYPE html>
                <html>
                <head>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>body{margin:0;display:flex;align-items:center;justify-content:center;height:100vh;}</style>
                </head>
                <body>\(code)</body>
                </html>
                """
                webView.loadHTMLString(wrapped, baseURL: nil)
            } else {
                // markdown
                let scroll = UIScrollView()
                scroll.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(scroll)
                NSLayoutConstraint.activate([
                    scroll.topAnchor.constraint(equalTo: containerView.topAnchor),
                    scroll.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    scroll.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    scroll.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
                let mdView = MarkdownContentView(style: MarkdownStyle.standard(textColor: Theme.current.textPrimary, secondary: Theme.current.textSecondary, accent: Theme.current.accent, codeBackground: Theme.current.codeBackground, isDark: Theme.current.isDark))
                mdView.translatesAutoresizingMaskIntoConstraints = false
                scroll.addSubview(mdView)
                NSLayoutConstraint.activate([
                    mdView.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 12),
                    mdView.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 12),
                    mdView.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -12),
                    mdView.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -12),
                    mdView.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -24)
                ])
                mdView.update(markdown: code)
                previewView = scroll
            }
        }

        // code view (always available)
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = true
        tv.font = Fonts.mono(size: 13)
        tv.text = code
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = Theme.current.codeBackground
        tv.textColor = Theme.current.textPrimary
        containerView.addSubview(tv)
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: containerView.topAnchor),
            tv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        codeTextView = tv

        if isPreviewable {
            // hide code initially
            codeTextView?.isHidden = true
        }
    }

    private func showCodeOrPreview(initial: Bool) {
        if !isPreviewable {
            previewView?.isHidden = true
            codeTextView?.isHidden = false
            return
        }
        let showPreview = segmentedControl.selectedSegmentIndex == 0
        previewView?.isHidden = !showPreview
        codeTextView?.isHidden = showPreview
    }

    @objc private func segmentChanged() {
        showCodeOrPreview(initial: false)
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = code
        showToast(NSLocalizedString("artifacts.copied", tableName: "Artifacts", comment: ""))
    }

    @objc private func shareTapped(_ sender: UIBarButtonItem) {
        let vc = UIActivityViewController(activityItems: [code], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.barButtonItem = sender
        }
        present(vc, animated: true, completion: nil)
    }

    @objc private func themeDidChange() {
        applyTheme()
        codeTextView?.backgroundColor = Theme.current.codeBackground
        codeTextView?.textColor = Theme.current.textPrimary
    }

    private func showToast(_ message: String) {
        let label = UILabel()
        label.text = message
        label.font = Fonts.sans(size: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])
        UIView.animate(withDuration: 0.3, delay: 1.2, options: [], animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
    }
}