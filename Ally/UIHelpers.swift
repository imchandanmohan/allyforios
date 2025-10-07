import SwiftUI
import UIKit

// Use a simultaneous tap so it NEVER blocks Button taps.
// (The old .gesture(...) could steal touches from child controls.)
extension View {
    func hideKeyboardOnTap() -> some View {
        modifier(HideKeyboardOnTap())
    }
}

private struct HideKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(              // ✅ does not cancel child taps
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            )
    }
}
