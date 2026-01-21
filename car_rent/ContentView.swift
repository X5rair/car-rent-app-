//
//  ContentView.swift
//  car_rent
//
//  Created by rair on 21.01.2026.
//

import SwiftUI
import MapKit
import Combine

final class WalletStore: ObservableObject {
    @Published var balanceKZT: Decimal = 0
}

struct ContentView: View {
    // Состояние авторизации и показа формы
    @State private var isLoggedIn = false
    @State private var showAuthSheet = false

    // Общий кошелёк для всех вкладок
    @StateObject private var wallet = WalletStore()

    var body: some View {
        TabView {
            NavigationStack {
                MainMapView()
                    .navigationTitle("Карта Алматы")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            if isLoggedIn {
                                Button("Выйти") {
                                    isLoggedIn = false
                                }
                            } else {
                                Button("Войти/Регистрация") {
                                    showAuthSheet = true
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showAuthSheet) {
                        LoginSheetView(isLoggedIn: $isLoggedIn) {
                            // onClose
                            showAuthSheet = false
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
        }
        .environmentObject(wallet)
    }
}

struct LoginSheetView: View {
    // Внешние биндинги/замыкание
    @Binding var isLoggedIn: Bool
    var onClose: () -> Void

    // Локальные состояния формы
    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Заголовок
                VStack(spacing: 8) {
                    Text(isSignUp ? "Регистрация" : "Вход")
                        .font(.title.bold())
                    Text(isSignUp ? "Создайте аккаунт" : "Войдите в аккаунт, чтобы арендовать авто")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Переключатель Вход / Регистрация
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

                // Поля ввода
                VStack(spacing: 14) {
                    if isSignUp {
                        TextField("Имя", text: $name)
                            .textContentType(.name)
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: name) { errorMessage = nil }
                    }

                    TextField("E‑mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: email) { errorMessage = nil }

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
                        .onChange(of: password) { errorMessage = nil }

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Ошибки / успех
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

                // Кнопка действия
                Button {
                    submit()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSignUp ? "Зарегистрироваться" : "Войти")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isActionEnabled ? Color.accentColor : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isActionEnabled || isLoading)
                .padding(.horizontal)

                Spacer(minLength: 12)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { onClose() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var isActionEnabled: Bool {
        if isSignUp {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isValidEmail(email)
            && password.count >= 6
        } else {
            return isValidEmail(email) && !password.isEmpty
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
                if password.count < 6 { reasons.append("пароль меньше 6 символов") }
                errorMessage = "Проверьте данные: " + reasons.joined(separator: ", ") + "."
            } else {
                var reasons: [String] = []
                if !isValidEmail(email) { reasons.append("e‑mail некорректен") }
                if password.isEmpty { reasons.append("пароль пустой") }
                errorMessage = "Проверьте данные: " + reasons.joined(separator: ", ") + "."
            }
            return
        }

        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isLoading = false
            isLoggedIn = true
            successMessage = isSignUp
                ? "Регистрация успешна! Добро пожаловать, \(name.isEmpty ? "водитель" : name)."
                : "Вход выполнен!"
            onClose()
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }
}

struct BalanceView: View {
    @EnvironmentObject private var wallet: WalletStore
    @State private var topUpText: String = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // Текущий баланс
            VStack(spacing: 6) {
                Text("Текущий баланс")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(formatKZT(wallet.balanceKZT))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }
            .padding(.top, 16)

            // Поле ввода суммы
            TextField("Сумма пополнения (KZT)", text: $topUpText)
                .keyboardType(.numberPad)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Сообщения
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

            // Кнопка пополнения
            Button {
                topUp()
            } label: {
                Text("Пополнить")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    private func topUp() {
        errorMessage = nil
        successMessage = nil

        // Преобразуем только цифры
        let digits = topUpText.filter { $0.isNumber }
        guard !digits.isEmpty, let amountInt = Int(digits), amountInt > 0 else {
            errorMessage = "Введите корректную сумму в тенге (только числа)."
            return
        }

        let amount = Decimal(amountInt)
        wallet.balanceKZT += amount
        successMessage = "Баланс пополнен на \(formatKZT(amount))."
        topUpText = ""
    }

    private func formatKZT(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0 // тенге без тиынов, при желании можно 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value) KZT"
    }
}

struct MainMapView: View {
    // Координаты
    private let almaty = CLLocationCoordinate2D(latitude: 43.238949, longitude: 76.889709)
    private let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    // Широкий регион по умолчанию
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.238949, longitude: 76.889709),
        span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
    )

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: false, userTrackingMode: nil)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 8) {
                Button {
                    region = MKCoordinateRegion(center: almaty, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))
                } label: {
                    Text("Алматы")
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Button {
                    region = MKCoordinateRegion(center: newYork, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))
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
    }
}

#Preview {
    ContentView()
}
