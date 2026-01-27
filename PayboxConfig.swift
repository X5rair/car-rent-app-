import Foundation

// Локальные безопасные типы, чтобы не зависеть от SDK-типов в конфиге.
// В проде можно вернуть Region/Language из SDK, когда они будут видны модулю.
enum PayboxRegion: String {
    case DEFAULT
    case RU
    case UZ
    case KG
}

enum PayboxLanguage: String {
    case ru
    case en
    case kz
    case de
}

enum PayboxConfig {
    // ВНИМАНИЕ: это плейсхолдеры для теста. В проде НЕ храните secretKey в приложении.
    static let merchantId: Int = 12345
    static let secretKey: String = "test_secret_key"

    // Регион API
    static let region: PayboxRegion = .DEFAULT

    // Тестовый режим
    static let testMode: Bool = true

    // Валюта и описание платежа
    static let currencyCode: String = "KZT"
    static let defaultDescription: String = "Пополнение кошелька"

    // Язык платёжной страницы
    static let language: PayboxLanguage = .ru
}
