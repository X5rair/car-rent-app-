import SwiftUI

struct PaymentWebContainer: UIViewRepresentable {
    let sdk: PayboxSdkProtocol
    let width: CGFloat
    let height: CGFloat
    let onLoadStarted: (() -> Void)?
    let onLoadFinished: (() -> Void)?

    func makeUIView(context: Context) -> PaymentView {
        let view = PaymentView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.delegate = context.coordinator
        sdk.setPaymentView(paymentView: view)
        return view
    }

    func updateUIView(_ uiView: PaymentView, context: Context) {
        // Ничего, PaymentView управляется SDK.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadStarted: onLoadStarted, onLoadFinished: onLoadFinished)
    }

    final class Coordinator: WebDelegate {
        let onLoadStarted: (() -> Void)?
        let onLoadFinished: (() -> Void)?

        init(onLoadStarted: (() -> Void)?, onLoadFinished: (() -> Void)?) {
            self.onLoadStarted = onLoadStarted
            self.onLoadFinished = onLoadFinished
        }

        func loadStarted() { onLoadStarted?() }
        func loadFinished() { onLoadFinished?() }
    }
}
