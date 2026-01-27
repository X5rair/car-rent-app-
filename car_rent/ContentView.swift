import SwiftUI
import MapKit
import Combine
import CryptoKit

final class WalletStore: ObservableObject {
    @Published var balanceKZT: Decimal = 0 {
        didSet { saveBalance() }
    }

    init() {
        loadBalance()
    }

    private func loadBalance() {
        let saved = UserDefaults.standard.string(forKey: "wallet.balanceKZT") ?? "0"
        if let decimal = Decimal(string: saved) {
            balanceKZT = decimal
        } else {
            balanceKZT = 0
        }
    }

    private func saveBalance() {
        let stringValue = NSDecimalNumber(decimal: balanceKZT).stringValue
        UserDefaults.standard.set(stringValue, forKey: "wallet.balanceKZT")
    }
}

private struct IsLoggedInKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isLoggedIn: Bool {
        get { self[IsLoggedInKey.self] }
        set { self[IsLoggedInKey.self] = newValue }
    }
}

private struct ShowAuthKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var showAuth: () -> Void {
        get { self[ShowAuthKey.self] }
        set { self[ShowAuthKey.self] = newValue }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case ru = "ru"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Системный"
        case .ru: return "Русский"
        case .en: return "English"
        }
    }

    var locale: Locale? {
        switch self {
        case .system: return nil
        case .ru: return Locale(identifier: "ru")
        case .en: return Locale(identifier: "en")
        }
    }
}

// MARK: - Auth

struct UserRecord: Codable, Equatable {
    var name: String
    var email: String
    var passwordHash: String
    var phone: String
}

final class AuthStore: ObservableObject {
    @Published private(set) var users: [String: UserRecord] = [:] // key = lowercased email
    @AppStorage("currentUserEmail") private var currentUserEmail: String = ""
    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var currentUser: UserRecord?

    private let usersKey = "auth.users.json"

    init() {
        loadUsers()
        restoreSession()
    }

    func register(name: String, email: String, password: String, phone: String) throws {
        let emailKey = emailKeyFor(email)
        guard users[emailKey] == nil else {
            throw AuthError.emailAlreadyExists
        }
        let record = UserRecord(name: name, email: emailKey, passwordHash: Self.hash(password), phone: phone)
        users[emailKey] = record
        saveUsers()
        setLoggedIn(user: record)
    }

    func login(email: String, password: String) throws {
        let emailKey = emailKeyFor(email)
        guard let record = users[emailKey] else {
            throw AuthError.userNotFound
        }
        guard record.passwordHash == Self.hash(password) else {
            throw AuthError.wrongPassword
        }
        setLoggedIn(user: record)
    }

    func logout() {
        currentUserEmail = ""
        currentUser = nil
        isLoggedIn = false
    }

    private func setLoggedIn(user: UserRecord) {
        currentUser = user
        currentUserEmail = user.email
        isLoggedIn = true
        UserDefaults.standard.set(user.name, forKey: "userName")
    }

    private func emailKeyFor(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func restoreSession() {
        guard !currentUserEmail.isEmpty, let user = users[currentUserEmail] else {
            isLoggedIn = false
            currentUser = nil
            return
        }
        currentUser = user
        isLoggedIn = true
        UserDefaults.standard.set(user.name, forKey: "userName")
    }

    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey) {
            if let decoded = try? JSONDecoder().decode([String: UserRecord].self, from: data) {
                users = decoded
            }
        }
    }

    private func saveUsers() {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: usersKey)
        }
    }

    static func hash(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    enum AuthError: LocalizedError {
        case emailAlreadyExists
        case userNotFound
        case wrongPassword

        var errorDescription: String? {
            switch self {
            case .emailAlreadyExists:
                return "Пользователь с таким e‑mail уже существует."
            case .userNotFound:
                return "Пользователь с таким e‑mail не найден."
            case .wrongPassword:
                return "Неверный пароль."
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var auth = AuthStore()
    @State private var showAuthFullScreen = false
    @StateObject private var wallet = WalletStore()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage("userName") private var storedUserName: String = ""
    @State private var showSplash = true

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                TabView {
                    NavigationStack {
                        MainMapView()
                            .navigationTitle("Карта Алматы")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    if auth.isLoggedIn {
                                        Button("Выйти") { auth.logout() }
                                    } else {
                                        Button("Войти/Регистрация") { showAuthFullScreen = true }
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Карта", systemImage: "map")
                    }

                    NavigationStack {
                        BalanceView()
                            .navigationTitle("Баланс")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .tabItem {
                        Label("Баланс", systemImage: "creditcard")
                    }

                    NavigationStack {
                        SettingsView()
                            .navigationTitle("Настройки")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .tabItem {
                        Label("Настройки", systemImage: "gearshape")
                    }
                }
                .onAppear {
                    if !auth.isLoggedIn {
                        showAuthFullScreen = true
                    }
                }
                .onChange(of: auth.isLoggedIn) { loggedIn in
                    showAuthFullScreen = !loggedIn
                }
                .fullScreenCover(isPresented: $showAuthFullScreen) {
                    AuthFullScreenView()
                        .environmentObject(auth)
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                }
            }
        }
        .environmentObject(wallet)
        .environmentObject(auth)
        .environment(\.isLoggedIn, auth.isLoggedIn)
        .environment(\.showAuth, { showAuthFullScreen = true })
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .environment(\.locale, currentLanguage.locale ?? Locale.autoupdatingCurrent)
    }
}

struct SplashView: View {
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)

                Text("car_rent")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.secondary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    scale = 1.0
                }
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Восстановленные экраны

struct BalanceView: View {
    @EnvironmentObject private var wallet: WalletStore
    @Environment(\.isLoggedIn) private var isLoggedIn
    @EnvironmentObject private var auth: AuthStore
    @State private var topUpText: String = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showAuthAlert = false
    @FocusState private var isTopUpFocused: Bool

    // Моки оплаты
    @State private var paymentAPI = MockPaymentAPI()
    @State private var payboxService: PayBoxSDKService? = nil
    @State private var isPaying = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Текущий баланс")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(formatKZT(wallet.balanceKZT))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }
            .padding(.top, 16)

            TextField("Сумма пополнения (KZT)", text: $topUpText)
                .keyboardType(.numberPad)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .disabled(!isLoggedIn || isPaying)
                .focused($isTopUpFocused)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button {
                    if isLoggedIn {
                        topUpLocal()
                    } else {
                        showAuthAlert = true
                    }
                } label: {
                    Text("Пополнить (локально)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoggedIn ? Color.accentColor : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isLoggedIn || isPaying)

                Button {
                    if isLoggedIn {
                        Task { await payWithPayBox() }
                    } else {
                        showAuthAlert = true
                    }
                } label: {
                    HStack {
                        if isPaying { ProgressView().tint(.white) }
                        Text("Оплатить картой (PayBox)")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoggedIn ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isLoggedIn || isPaying)
            }

            Spacer()
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            isTopUpFocused = false
        }
        .onAppear {
            // Подключаем реальный сервис PayBox поверх SDK
            payboxService = RealPayBoxSDKService()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    isTopUpFocused = false
                }
            }
        }
        .alert("Войдите, чтобы пополнить баланс", isPresented: $showAuthAlert) {
            Button("ОК", role: .cancel) { }
        } message: {
            Text("Для пополнения баланса необходимо войти или зарегистрироваться.")
        }
    }

    private func topUpLocal() {
        errorMessage = nil
        successMessage = nil

        let digits = topUpText.filter { $0.isNumber }
        guard !digits.isEmpty, let amountInt = Int(digits), amountInt > 0 else {
            errorMessage = "Введите корректную сумму в тенге (только числа)."
            return
        }

        let amount = Decimal(amountInt)
        wallet.balanceKZT += amount
        successMessage = "Баланс пополнен на \(formatKZT(amount))."
        topUpText = ""
        isTopUpFocused = false
    }

    private func payAmountInt() -> Int? {
        let digits = topUpText.filter { $0.isNumber }
        guard !digits.isEmpty, let amountInt = Int(digits), amountInt > 0 else { return nil }
        return amountInt
    }

    private func userId() -> String {
        auth.currentUser?.email ?? "guest"
    }

    private func payWithPayBox() async {
        errorMessage = nil
        successMessage = nil
        isPaying = true
        defer { isPaying = false }

        guard let amountInt = payAmountInt() else {
            errorMessage = "Введите корректную сумму (только числа)."
            return
        }

        do {
            // 1) Создать “интент” на сервере (мок)
            let intent = try await paymentAPI.createIntent(
                amountKZT: amountInt,
                userId: userId(),
                email: auth.currentUser?.email,
                phone: auth.currentUser?.phone
            )

            // 2) Запустить PayBox SDK (реальный сервис)
            guard let payboxService else {
                errorMessage = "Сервис оплаты не инициализирован."
                return
            }
            let result = await payboxService.startPayment(intent: intent)

            switch result {
            case .success:
                // 3) Опросить статус (в моке статус уже success не обязателен, но оставим логику)
                try await Task.sleep(nanoseconds: 600_000_000)
                let status = try await paymentAPI.fetchStatus(paymentId: intent.paymentId)
                if status.status == .succeeded {
                    wallet.balanceKZT += Decimal(status.amountKZT)
                    successMessage = "Оплата прошла успешно на \(formatKZT(Decimal(status.amountKZT)))."
                    topUpText = ""
                } else {
                    errorMessage = "Оплата не подтверждена (статус: \(status.status.rawValue))."
                }
            case .canceled:
                errorMessage = "Оплата отменена."
            case .failure(let msg):
                errorMessage = "Ошибка оплаты: \(msg)"
            }
        } catch {
            errorMessage = "Не удалось выполнить оплату: \(error.localizedDescription)"
        }
    }

    private func formatKZT(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value) KZT"
    }
}

struct Car: Identifiable {
    let id: UUID
    let title: String
    let plate: String
    let tariffPerMinuteKZT: Int
    let coordinate: CLLocationCoordinate2D

    init(id: UUID = UUID(), title: String, plate: String, tariffPerMinuteKZT: Int, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.title = title
        self.plate = plate
        self.tariffPerMinuteKZT = tariffPerMinuteKZT
        self.coordinate = coordinate
    }
}

struct MainMapView: View {
    private let almaty = CLLocationCoordinate2D(latitude: 43.238949, longitude: 76.889709)
    private let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.238949, longitude: 76.889709),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    @State private var cars: [Car] = [
        Car(
            title: "Kia Rio",
            plate: "123 ABC 02",
            tariffPerMinuteKZT: 60,
            coordinate: CLLocationCoordinate2D(latitude: 43.2389, longitude: 76.8895)
        )
    ]

    @State private var selectedCar: Car?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: false, userTrackingMode: nil, annotationItems: cars) { car in
                MapAnnotation(coordinate: car.coordinate) {
                    VStack(spacing: 4) {
                        Button {
                            selectedCar = car
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 34, height: 34)
                                Image(systemName: "car.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        Text(car.title)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 8) {
                Button {
                    region = MKCoordinateRegion(center: almaty, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
                } label: {
                    Text("Алматы")
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Button {
                    region = MKCoordinateRegion(center: newYork, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
                } label: {
                    Text("Нью‑Йорк")
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding()
        }
        .sheet(item: $selectedCar) { car in
            CarDetailsView(car: car)
                .presentationDetents([.medium])
        }
    }
}

struct CarDetailsView: View {
    let car: Car

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "car.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(car.title)
                            .font(.title3).bold()
                        Text(car.plate)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack {
                    Image(systemName: "tenge.sign.circle")
                        .foregroundStyle(.secondary)
                    Text("Тариф: \(car.tariffPerMinuteKZT) ₸/мин")
                }

                HStack {
                    Image(systemName: "location")
                        .foregroundStyle(.secondary)
                    Text("Координаты: \(String(format: "%.4f", car.coordinate.latitude)), \(String(format: "%.4f", car.coordinate.longitude))")
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Button {
                    // В демо просто показать, что действие сработало
                } label: {
                    Text("Забронировать")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
            .navigationTitle("Автомобиль")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var wallet: WalletStore
    @Environment(\.isLoggedIn) private var isLoggedIn
    @Environment(\.showAuth) private var showAuth
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage("userName") private var storedUserName: String = ""

    var body: some View {
        Form {
            if isLoggedIn {
                Section("Профиль") {
                    HStack {
                        Text("Имя")
                        Spacer()
                        Text(storedUserName.isEmpty ? "—" : storedUserName)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("E‑mail")
                        Spacer()
                        Text(auth.currentUser?.email ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Телефон")
                        Spacer()
                        Text(formattedKZPhoneForDisplay(auth.currentUser?.phone ?? ""))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Кошелёк") {
                    HStack {
                        Text("Баланс")
                        Spacer()
                        Text(NumberFormatter.kzt.string(from: wallet.balanceKZT as NSDecimalNumber) ?? "")
                            .fontWeight(.semibold)
                    }
                }

                Section("Предпочтения") {
                    Toggle("Тёмная тема", isOn: $isDarkMode)
                    Toggle("Уведомления", isOn: $notificationsEnabled)
                    Picker("Язык", selection: $appLanguageRaw) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        Text("Выйти")
                    }
                }
            } else {
                Section {
                    Button {
                        showAuth()
                    } label: {
                        Text("Войти/Регистрация")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }

    private func formattedKZPhoneForDisplay(_ digits: String) -> String {
        guard digits.count == 11, digits.first == "7" else { return digits.isEmpty ? "—" : digits }
        let rest = digits.dropFirst()
        func chunk(_ start: Int, _ len: Int) -> String {
            let s = rest.index(rest.startIndex, offsetBy: min(start, rest.count), limitedBy: rest.endIndex) ?? rest.endIndex
            let e = rest.index(s, offsetBy: min(len, rest.distance(from: s, to: rest.endIndex)), limitedBy: rest.endIndex) ?? rest.endIndex
            return String(rest[s..<e])
        }
        var result = "+7"
        let g1 = chunk(0, 3); if !g1.isEmpty { result += " " + g1 }
        let g2 = chunk(3, 3); if !g2.isEmpty { result += " " + g2 }
        let g3 = chunk(6, 2); if !g3.isEmpty { result += " " + g3 }
        let g4 = chunk(8, 2); if !g4.isEmpty { result += " " + g4 }
        return result
    }
}

private extension NumberFormatter {
    static let kzt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "KZT"
        f.maximumFractionDigits = 0
        return f
    }()
}

#Preview {
    ContentView()
}
