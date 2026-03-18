/// ToastOverlayView — Stack of visible toast notifications.
///
/// Observes NotificationManager's visible toast queue and renders up to 3
/// ToastViews in a bottom-aligned vertical stack. Positioned above the
/// StatusToolbar in ContentView's VStack.
import SwiftUI

// MARK: - ToastOverlayView

struct ToastOverlayView: View {
    let notificationManager: NotificationManager

    var body: some View {
        VStack(spacing: 6) {
            ForEach(notificationManager.visibleToasts) { toast in
                ToastView(toast: toast) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        notificationManager.dismiss(toast.id)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: notificationManager.visibleToasts.map(\.id))
        // Prevent invisible empty overlay from intercepting taps on the farm scene.
        .allowsHitTesting(!notificationManager.visibleToasts.isEmpty)
    }
}
