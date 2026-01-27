import Foundation

enum PayBoxResult: Sendable {
    case success
    case canceled
    case failure(String)
}

protocol PayBoxSDKService {
    func startPayment(intent: PaymentIntent) async -> PayBoxResult
}

// MARK: - Mock implementation (замените на реальный вызов SDK PayBox)

final class MockPayBoxSDKService: PayBoxSDKService {
    // Ссылка на мок-API, чтобы проставить успешный статус после “оплаты”
    private let paymentAPI: MockPaymentAPI

    init(paymentAPI: MockPaymentAPI) {
        self.paymentAPI = paymentAPI
    }

    func startPayment(intent: PaymentIntent) async -> PayBoxResult {
        // Имитация UI SDK: ждём 1.5 сек, возвращаем успех
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        // Отметим в мок-хранилище, что платёж успешен
        paymentAPI.markSucceeded(paymentId: intent.paymentId)
        return .success
    }
}
