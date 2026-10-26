import Foundation

/// Web pages the app links to.
enum AppLinks {
    // The page goes up on Cloudflare Pages once Mike picks the address (安全与法律, 隐私政策 发布方案 v0).
    // Until then Settings shows no privacy row, so nothing links to a page that doesn't exist.
    /// The privacy policy, or nil while it has no address yet.
    static let privacyPolicy: URL? = nil
}
