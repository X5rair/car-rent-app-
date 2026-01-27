import UIKit

// MARK: - Stubs to let the app compile without the real Paybox SDK.
// Remove this file when you integrate the real SDK.

protocol WebDelegate: AnyObject {
    func loadStarted()
    func loadFinished()
}

final class PaymentView: UIView {
    weak var delegate: WebDelegate?

    // В реальном SDK этот вью сам управляет загрузкой веб-страницы.
    // Для стуба можем имитировать колбэки.
    func simulateLoad() {
        delegate?.loadStarted()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.delegate?.loadFinished()
        }
    }
}

// MARK: - Paybox SDK protocol and facade stubs

protocol PayboxSdkProtocol: AnyObject {
    func setPaymentView(paymentView: PaymentView)
    func config() -> PayboxConfigFacade
    func createPayment(amount: Float,
                       description: String,
                       orderId: String,
                       userId: String?,
                       extraParams: [String: String]?,
                       completion: @escaping (_ payment: Any?, _ error: PayboxError?) -> Void)
}

// Фасад конфигурации SDK
protocol PayboxConfigFacade {
    func testMode(enabled: Bool)
    func setRegion(region: PayboxRegion)
    func setLanguage(language: PayboxLanguage)
    func setCurrencyCode(code: String)
    func setUserEmail(userEmail: String)
    func setUserPhone(userPhone: String)
}

// Ошибка SDK (минимальная)
struct PayboxError: Error {
    let description: String
}

// Простая заглушка SDK
final class PayboxSdk: PayboxSdkProtocol {
    private var paymentView: PaymentView?
    private let configuration = PayboxConfigFacadeStub()

    static func initialize(merchantId: Int, secretKey: String) -> PayboxSdkProtocol {
        PayboxSdk()
    }

    func setPaymentView(paymentView: PaymentView) {
        self.paymentView = paymentView
    }

    func config() -> PayboxConfigFacade {
        configuration
    }

    func createPayment(amount: Float,
                       description: String,
                       orderId: String,
                       userId: String?,
                       extraParams: [String: String]?,
                       completion: @escaping (_ payment: Any?, _ error: PayboxError?) -> Void) {
        // Имитация: сообщим, что веб начал/завершил загрузку и вернём "успех"
        paymentView?.simulateLoad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(["orderId": orderId], nil)
        }
    }
}

// Реализация фасада конфигурации (заглушка)
final class PayboxConfigFacadeStub: PayboxConfigFacade {
    func testMode(enabled: Bool) {}
    func setRegion(region: PayboxRegion) {}
    func setLanguage(language: PayboxLanguage) {}
    func setCurrencyCode(code: String) {}
    func setUserEmail(userEmail: String) {}
    func setUserPhone(userPhone: String) {}
}
