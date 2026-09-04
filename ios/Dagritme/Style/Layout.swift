import SwiftUI
import UIKit

enum SafeArea {
    static var top: CGFloat { window?.safeAreaInsets.top ?? 0 }
    static var bottom: CGFloat { window?.safeAreaInsets.bottom ?? 0 }

    private static var window: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.keyWindow
    }
}
