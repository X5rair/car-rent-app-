import Foundation
import SwiftUI

// Реальный сервис, использующий PayboxSdk и PaymentView (веб-страница без Apple Pay)
final class RealPayBoxSDKService: PayBoxSDKService {

    private let sdk: PayboxSdkProtocol

    // Состояние показа WebView. Хранится внутри сервиса, но управляется извне через биндинги.
    @MainActor
    private(set) var isPresentingWeb: Binding<Bool>?

    // Колбэк завершения текущего платежа
    private var completion: ((PayBoxResult) -> Void)?

    init(merchantId: Int = PayboxConfig.merchantId,
         secretKey: String = PayboxConfig.secretKey,
         region: PayboxRegion = PayboxConfig.region,
         testMode: Bool = PayboxConfig.testMode,
         language: PayboxLanguage = PayboxConfig.language,
         currencyCode: String = PayboxConfig.currencyCode) {
        let sdk = PayboxSdk.initialize(merchantId: merchantId, secretKey: secretKey)
        sdk.config().testMode(enabled: testMode)
        sdk.config().setRegion(region: region)
        sdk.config().setLanguage(language: language)
        sdk.config().setCurrencyCode(code: currencyCode)
        self.sdk = sdk
    }

    // Этот метод будет вызываться из BalanceView.
    // Он создаёт платёж и открывает redirectUrl в PaymentView через SwiftUI sheet.
    func startPayment(intent: PaymentIntent) async -> PayBoxResult {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                // Откроем веб-лист
                let presenting = Binding<Bool>(
                    get: { true },
                    set: { _ in }
                )
                self.isPresentingWeb = presenting

                // Подготовим параметры
                let amount = Float(intent.amountKZT)
                let description = intent.description.isEmpty ? PayboxConfig.defaultDescription : intent.description
                // Если у вас есть собственный orderId — можно передать через additionalParams["orderId"]
                let orderId = intent.additionalParams["orderId"] ?? UUID().uuidString
                let userId = intent.additionalParams["userId"]

                // Проставим email/phone, если есть
                if let email = intent.additionalParams["email"], !email.isEmpty {
                    self.sdk.config().setUserEmail(userEmail: email)
                }
                if let phone = intent.additionalParams["phone"], !phone.isEmpty {
                    self.sdk.config().setUserPhone(userPhone: phone)
                }

                // Создаём платёж. SDK вернёт redirectUrl и сам откроет его в PaymentView,
                // который мы выдадим через SwiftUI sheet (см. buildPaymentSheet ниже).
                self.presentPaymentSheet { [weak self] in
                    guard let self else { return }
                    self.sdk.createPayment(amount: amount,
                                           description: description,
                                           orderId: orderId,
                                           userId: userId,
                                           extraParams: nil) { payment, error in
                        // В этом колбэке SDK уже отработал: если был redirectUrl, PaymentView открыла страницу.
                        // Финальный успех/ошибка придут из PaymentView.sucessOrFailure, который мы ловим в presentPaymentSheet.
                        if let error {
                            self.finish(with: .failure(error.description), continuation: continuation)
                        } else if payment == nil {
                            self.finish(with: .failure("Не удалось инициализировать платёж"), continuation: continuation)
                        } else {
                            // Ничего не делаем здесь — ждём сигнал из веб-страницы (success/failure)
                        }
                    }
                } onResult: { [weak self] success in
                    guard let self else { return }
                    if success {
                        self.finish(with: .success, continuation: continuation)
                    } else {
                        self.finish(with: .failure("Оплата не удалась"), continuation: continuation)
                    }
                }
            }
        }
    }

    @MainActor
    private func finish(with result: PayBoxResult, continuation: CheckedContinuation<PayBoxResult, Never>) {
        // Закрыть веб
        isPresentingWeb?.wrappedValue = false
        isPresentingWeb = nil
        continuation.resume(returning: result)
    }

    // Показывает SwiftUI лист с PaymentView и отдаёт два колбэка:
    // - onAppearStart: где дергаем sdk.createPayment(...)
    // - onResult: где получаем true/false из PaymentView.sucessOrFailure
    @MainActor
    private func presentPaymentSheet(onAppearStart: @escaping () -> Void,
                                     onResult: @escaping (Bool) -> Void) {
        // Построим отдельное окно (sheet) для текущей сцены. Мы не можем из сервиса напрямую показать .sheet в SwiftUI,
        // поэтому создадим окно поверх на время оплаты.
        let hosting = UIHostingController(rootView:
            PaymentWebSheetView(sdk: sdk,
                                onStart: onAppearStart,
                                onResult: onResult)
        )
        hosting.modalPresentationStyle = .formSheet
        UIApplication.shared.topMostViewController()?.present(hosting, animated: true, completion: nil)
    }
}

// Вспомогательный SwiftUI экран, который добавляет PaymentView и запускает createPayment
private struct PaymentWebSheetView: View {
    let sdk: PayboxSdkProtocol
    let onStart: () -> Void
    let onResult: (Bool) -> Void

    @State private var containerSize: CGSize = .init(width: UIScreen.main.bounds.width,
                                                     height: UIScreen.main.bounds.height * 0.75)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Оплата PayBox")
                    .font(.headline)
                Spacer()
                Button("Закрыть") {
                    onResult(false) // трактуем закрытие как неуспех/отмену
                    dismiss()
                }
            }
            .padding()
            Divider()

            PaymentWebContainer(sdk: sdk,
                                width: containerSize.width,
                                height: containerSize.height,
                                onLoadStarted: nil,
                                onLoadFinished: nil)
                .frame(height: containerSize.height)
                .onAppear {
                    // Запускаем создание платежа
                    onStart()
                }
        }
        .onAppear {
            // актуализируем размеры
            containerSize = CGSize(width: UIScreen.main.bounds.width,
                                   height: UIScreen.main.bounds.height * 0.75)
        }
    }

    @Environment(\.dismiss) private var dismiss
}

// Утилита, чтобы найти верхний контроллер для показа листа
private extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}
