import Foundation
import Combine

struct LocalChatMessage: Identifiable, Sendable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

@MainActor
final class ChatLocalService: ObservableObject {
    @Published private(set) var messages: [LocalChatMessage] = []

    func reset() {
        messages = []
    }

    func greetIfNeeded(context: [String: String]) {
        guard messages.isEmpty else { return }
        let greeting = LocalChatMessage(role: .assistant, content: makeGreeting(context: context))
        messages.append(greeting)
    }

    func ask(_ text: String, context: [String: String]) async -> String {
        let user = LocalChatMessage(role: .user, content: text)
        messages.append(user)

        // Имитация “обработки” (можно убрать задержку)
        try? await Task.sleep(nanoseconds: 150_000_000)

        let replyText = makeAnswer(for: text, context: context)
        let assistant = LocalChatMessage(role: .assistant, content: replyText)
        messages.append(assistant)
        return replyText
    }

    // MARK: - Локальная логика ответов (FAQ + подсказки по валидации)

    private func makeGreeting(context: [String: String]) -> String {
        var parts: [String] = []
        parts.append("Привет! Я офлайн‑помощник PASSION MOTORS. Отвечу на вопросы по входу, регистрации, OTP и балансу.")
        if let mode = context["mode"] {
            if mode == "registration" {
                parts.append("Сейчас вы на экране регистрации.")
            } else if mode == "login" {
                parts.append("Сейчас вы на экране входа.")
            }
        }
        if let err = context["lastError"], !err.isEmpty {
            parts.append("Вижу последнее сообщение об ошибке: “\(err)”. Могу помочь разобраться.")
        }
        return parts.joined(separator: " ")
    }

    private func makeAnswer(for text: String, context: [String: String]) -> String {
        let q = text.lowercased()

        // Быстрые ответы по ключевым словам
        if q.contains("регист") || q.contains("зарегистр") {
            return registrationHelp(context: context)
        }
        if q.contains("вход") || q.contains("логин") {
            return loginHelp(context: context)
        }
        if q.contains("код") || q.contains("otp") || q.contains("смс") {
            return otpHelp(context: context)
        }
        if q.contains("баланс") || q.contains("попол") || q.contains("оплат") || q.contains("paybox") {
            return balanceHelp()
        }
        if q.contains("телефон") || q.contains("+7") {
            return phoneHelp(context: context)
        }
        if q.contains("email") || q.contains("почт") || q.contains("e-mail") {
            return emailHelp(context: context)
        }
        if q.contains("парол") {
            return passwordHelp(context: context)
        }
        if q.contains("язык") || q.contains("рус") || q.contains("english") {
            return "Язык интерфейса можно поменять в Профиле → Язык. Доступны: системный, русский, английский."
        }
        if q.contains("темн") || q.contains("свет") || q.contains("тема") {
            return "Тему можно переключить в Профиле → Тёмная тема."
        }

        // Если контекст подсказывает ошибки — попробуем дать совет
        if let err = context["lastError"], !err.isEmpty {
            return "Похоже, форма не проходит валидацию: “\(err)”. Проверьте, что e‑mail корректный (есть @ и точка), телефон в формате +7 XXX XXX XX XX, а пароль не короче 8 символов."
        }

        // Общее дефолтное
        return "Задайте вопрос про регистрацию, вход, код подтверждения, пополнение баланса или настройки — подскажу."
    }

    private func registrationHelp(context: [String: String]) -> String {
        var tips: [String] = []
        tips.append("Для регистрации заполните Имя, E‑mail, Телефон (+7) и Пароль (минимум 8 символов), затем нажмите «Зарегистрироваться».")
        if let nameProvided = context["nameProvided"], nameProvided == "no" {
            tips.append("Имя пустое — заполните поле «Имя».")
        }
        if let emailValid = context["emailValid"], emailValid == "no" {
            tips.append("E‑mail выглядит некорректно — проверьте наличие «@» и домена (например, .com).")
        }
        if let phoneValid = context["phoneValid"], phoneValid == "no" {
            let masked = context["phoneMasked"] ?? "+7 *** *** ** **"
            tips.append("Телефон должен быть в формате +7 XXX XXX XX XX. Сейчас: \(masked).")
        }
        tips.append("После успешной регистрации откроется окно с кодом подтверждения (мок), введите 123456.")
        return tips.joined(separator: " ")
    }

    private func loginHelp(context: [String: String]) -> String {
        var tips: [String] = []
        tips.append("Для входа укажите E‑mail и Пароль (минимум 8 символов), затем нажмите «Войти».")
        if let emailValid = context["emailValid"], emailValid == "no" {
            tips.append("E‑mail выглядит некорректно — проверьте формат.")
        }
        tips.append("После входа откроется окно подтверждения (мок): введите код 123456.")
        return tips.joined(separator: " ")
    }

    private func otpHelp(context: [String: String]) -> String {
        let masked = context["phoneMasked"] ?? "+7 *** *** ** **"
        return "Код подтверждения в мок‑режиме — 123456. Окно появляется после входа/регистрации. Номер отображается как \(masked)."
    }

    private func balanceHelp() -> String {
        "Баланс пополняется во вкладке «Баланс». Можно ввести сумму и нажать «Пополнить» (локально), либо оплатить картой (PayBox). В мок‑режиме оплата имитируется."
    }

    private func phoneHelp(context: [String: String]) -> String {
        let masked = context["phoneMasked"] ?? "+7 *** *** ** **"
        if let phoneValid = context["phoneValid"], phoneValid == "no" {
            return "Телефон должен начинаться с +7 и содержать 11 цифр. Пример: +7 777 123 45 67. Сейчас: \(masked)."
        } else {
            return "Формат телефона: +7 XXX XXX XX XX. Текущий: \(masked)."
        }
    }

    private func emailHelp(context: [String: String]) -> String {
        if let emailValid = context["emailValid"], emailValid == "no" {
            return "E‑mail должен содержать «@» и домен (например, user@example.com). Проверьте опечатки."
        } else {
            return "Проверьте, что e‑mail указан корректно и совпадает с тем, что вы использовали при регистрации."
        }
    }

    private func passwordHelp(context: [String: String]) -> String {
        "Пароль должен быть не короче 8 символов. Не отправляйте пароль в сообщениях. Если забыли пароль — используйте восстановление (когда появится в приложении)."
    }
}
