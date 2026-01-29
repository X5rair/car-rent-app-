import SwiftUI
// import FirebaseAuth // Вернём, когда снова подключим реальный SMS

struct AuthFullScreenView: View {
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("userName") private var storedUserName: String = ""

    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // Переход к OTP (мок-режим)
    @State private var requireOTP = false
    @State private var otpPhoneMasked: String = ""

    // ИИ-помощник
    @State private var showAI = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.blue.opacity(0.35)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Hero
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 160, height: 160)
                                .blur(radius: 2)
                            Image("hyundai_sonata")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .blue.opacity(0.6), radius: 12, x: 0, y: 0)
                        }
                        Text("PASSION MOTORS")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                        Text("PREMIUM CAR SHARING SERVICE")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                            .tracking(1)
                    }
                    .padding(.top, 28)

                    VStack(spacing: 6) {
                        Text("Стиль. Мощь. Совершенство.")
                            .font(.title3).bold()
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Вы выбираете — мы реализуем. Арендуйте премиум‑авто когда хотите и на сколько хотите.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Picker("", selection: $isSignUp) {
                        Text("Вход").tag(false)
                        Text("Регистрация").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: isSignUp) {
                        errorMessage = nil
                        successMessage = nil
                    }

                    // Форма
                    VStack(spacing: 14) {
                        if isSignUp {
                            TextField("Имя", text: $name)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .disableAutocorrection(true)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .onChange(of: name) { _ in errorMessage = nil }

                            TextField("+7 XXX XXX XX XX", text: $phone)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .onChange(of: phone) { newValue in
                                    errorMessage = nil
                                    phone = formatKZPhone(newValue)
                                }
                        }

                        TextField("E‑mail", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .onChange(of: email) { _ in errorMessage = nil }

                        HStack {
                            Group {
                                if isPasswordVisible {
                                    TextField("Пароль", text: $password)
                                } else {
                                    SecureField("Пароль", text: $password)
                                }
                            }
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: password) { _ in errorMessage = nil }

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .padding(.horizontal)

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

                    Button {
                        submit()
                    } label: {
                        HStack {
                            if isLoading { ProgressView().tint(.white) }
                            Text(isSignUp ? "Зарегистрироваться" : "Войти")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isActionEnabled ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .blue.opacity(0.35), radius: 12, x: 0, y: 6)
                    }
                    .disabled(!isActionEnabled || isLoading)
                    .padding(.horizontal)

                    // Кнопка ИИ‑помощника
                    Button {
                        showAI = true
                    } label: {
                        Label("Спросить ИИ", systemImage: "bubble.left.and.bubble.right.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.85))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Text("Нажимая «\(isSignUp ? "Зарегистрироваться" : "Войти")», вы соглашаетесь с Условиями оферты и Политикой конфиденциальности.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 28)
                }
            }
        }
        .interactiveDismissDisabled(true)
        .navigationBarHidden(true)
        // Мок-режим: показываем OTP через sheet. Никогда не закрываем автоматически.
        .sheet(isPresented: $requireOTP) {
            OtpVerificationView(
                phoneMasked: otpPhoneMasked.isEmpty ? "ваш номер" : otpPhoneMasked,
                onCancel: {
                    requireOTP = false
                },
                onVerified: {
                    requireOTP = false
                }
            )
        }
        // Чат ИИ
        .sheet(isPresented: $showAI) {
            ChatSheetView(initialContext: aiContext())
        }
    }

    private var isActionEnabled: Bool {
        if isSignUp {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isValidEmail(email)
            && isValidKZPhone(phone)
            && password.count >= 8
        } else {
            return isValidEmail(email) && password.count >= 8
        }
    }

    private func submit() {
        errorMessage = nil
        successMessage = nil

        guard isActionEnabled else {
            if isSignUp {
                var reasons: [String] = []
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { reasons.append("имя пустое") }
                if !isValidEmail(email) { reasons.append("e‑mail некорректен") }
                if !isValidKZPhone(phone) { reasons.append("телефон некорректен (+7 XXX XXX XX XX)") }
                if password.count < 8 { reasons.append("пароль меньше 8 символов") }
                errorMessage = "Проверьте данные: " + reasons.joined(separator: ", ") + "."
            } else {
                var reasons: [String] = []
                if !isValidEmail(email) { reasons.append("e‑mail некорректен") }
                if password.count < 8 { reasons.append("пароль меньше 8 символов") }
                errorMessage = "Проверьте данные: " + reasons.joined(separator: ", ") + "."
            }
            return
        }

        isLoading = true

        // Сразу выполняем локальную регистрацию/вход
        do {
            if isSignUp {
                try auth.register(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                  email: email,
                                  password: password,
                                  phone: normalizedKZPhone(phone))
                storedUserName = auth.currentUser?.name ?? ""
                successMessage = "Регистрация успешна!"
            } else {
                try auth.login(email: email, password: password)
                storedUserName = auth.currentUser?.name ?? ""
                successMessage = "Вход выполнен!"
            }
        } catch {
            isLoading = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Ошибка входа/регистрации."
            return
        }

        // Мок: без задержек открываем OTP и держим sheet до действий пользователя
        let digits = normalizedKZPhone(isSignUp ? phone : (auth.currentUser?.phone ?? phone))
        otpPhoneMasked = maskedPhone(digits)
        isLoading = false
        requireOTP = true
    }

    private func maskedPhone(_ digits: String) -> String {
        guard digits.count == 11 else { return digits }
        let tail = String(digits.suffix(2))
        return "+7 *** *** ** " + tail
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    private func isValidKZPhone(_ input: String) -> Bool {
        let digits = normalizedKZPhone(input)
        return digits.count == 11 && digits.first == "7"
    }

    private func normalizedKZPhone(_ input: String) -> String {
        var digits = input.filter(\.isNumber)
        if digits.first == "8" && digits.count == 11 {
            digits.removeFirst()
            digits = "7" + digits
        }
        if digits.count > 11 {
            digits = String(digits.prefix(11))
        }
        return digits
    }

    private func formatKZPhone(_ input: String) -> String {
        var digits = input.filter(\.isNumber)
        if digits.first == "8" {
            digits.removeFirst()
            digits = "7" + digits
        }
        if digits.first != "7" {
            digits = (digits.first == nil) ? "7" : "7" + digits.drop(while: { $0 == "7" })
        }
        if digits.count > 11 {
            digits = String(digits.prefix(11))
        }
        var result = "+7"
        let rest = digits.dropFirst()
        func chunk(_ start: Int, _ len: Int) -> String {
            let s = rest.index(rest.startIndex, offsetBy: min(start, rest.count), limitedBy: rest.endIndex) ?? rest.endIndex
            let e = rest.index(s, offsetBy: min(len, rest.distance(from: s, to: rest.endIndex)), limitedBy: rest.endIndex) ?? rest.endIndex
            return String(rest[s..<e])
        }
        let g1 = chunk(0, 3); if !g1.isEmpty { result += " " + g1 }
        let g2 = chunk(3, 3); if !g2.isEmpty { result += " " + g2 }
        let g3 = chunk(6, 2); if !g3.isEmpty { result += " " + g3 }
        let g4 = chunk(8, 2); if !g4.isEmpty { result += " " + g4 }
        return result
    }

    // Собираем безопасный контекст для ИИ
    private func aiContext() -> [String: String] {
        var ctx: [String: String] = [:]
        ctx["mode"] = isSignUp ? "registration" : "login"
        ctx["emailValid"] = isValidEmail(email) ? "yes" : "no"
        if isSignUp {
            ctx["nameProvided"] = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "no" : "yes"
            ctx["phoneValid"] = isValidKZPhone(phone) ? "yes" : "no"
        }
        if let errorMessage { ctx["lastError"] = errorMessage }
        // Телефон маскируем
        let digits = normalizedKZPhone(phone)
        ctx["phoneMasked"] = maskedPhone(digits)
        return ctx
    }
}

