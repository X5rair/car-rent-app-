import Foundation

struct PaymentIntent: Codable, Sendable {
    let paymentId: String
    let amountKZT: Int
    let currency: String
    let description: String
    // Параметры, которые обычно нужны SDK/серверу PayBox.
    // Здесь можно добавить merchantId, invoiceId, signature и т.п. при реальной интеграции.
    let additionalParams: [String: String]
}

enum PaymentStatusValue: String, Codable, Sendable {
    case created
    case processing
    case succeeded
    case failed
    case canceled
}

struct PaymentStatus: Codable, Sendable {
    let paymentId: String
    let status: PaymentStatusValue
    let amountKZT: Int
}

protocol PaymentAPI {
    func createIntent(amountKZT: Int, userId: String, email: String?, phone: String?) async throws -> PaymentIntent
    func fetchStatus(paymentId: String) async throws -> PaymentStatus
}

// MARK: - Mock implementation (замените на реальный URLSession-вызов вашего бэкенда)

final class MockPaymentAPI: PaymentAPI {
    private var storage: [String: PaymentStatus] = [:]

    func createIntent(amountKZT: Int, userId: String, email: String?, phone: String?) async throws -> PaymentIntent {
        // Имитация: создаём paymentId и кладём статус created
        let id = "pbx_" + UUID().uuidString.prefix(8)
        let status = PaymentStatus(paymentId: id, status: .created, amountKZT: amountKZT)
        storage[id] = status

        // Возвращаем “интент”, как будто сервер подготовил его для PayBox SDK
        return PaymentIntent(
            paymentId: id,
            amountKZT: amountKZT,
            currency: "KZT",
            description: "Пополнение кошелька",
            additionalParams: [
                "userId": userId,
                "email": email ?? "",
                "phone": phone ?? ""
            ]
        )
    }

    func fetchStatus(paymentId: String) async throws -> PaymentStatus {
        // Имитация: если SDK уже “прошёл”, меняем статус на succeeded
        if var current = storage[paymentId] {
            return current
        } else {
            // Если не нашли — считаем, что отменён
            return PaymentStatus(paymentId: paymentId, status: .canceled, amountKZT: 0)
        }
    }

    // Вспомогательный метод для мока: пометить успешным
    func markSucceeded(paymentId: String) {
        if let current = storage[paymentId] {
            storage[paymentId] = PaymentStatus(paymentId: current.paymentId, status: .succeeded, amountKZT: current.amountKZT)
        }
    }
}
