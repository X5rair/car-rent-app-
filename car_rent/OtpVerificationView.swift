import SwiftUI

struct OtpVerificationView: View {
    let phoneMasked: String
    let onCancel: () -> Void
    let onVerified: () -> Void

    @State private var code: [String] = ["", "", "", ""]
    @FocusState private var focusedIndex: Int?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.blue.opacity(0.35)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Введите код")
                        .font(.title3).bold()
                        .foregroundStyle(.white)
                    Text("Мы отправили 4‑значный код на \(phoneMasked)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { idx in
                        TextField("", text: Binding(
                            get: { code[idx] },
                            set: { newValue in
                                let filtered = newValue.filter(\.isNumber)
                                if filtered.count > 1 {
                                    // вставка из буфера: возьмём только первый символ
                                    code[idx] = String(filtered.prefix(1))
                                } else {
                                    code[idx] = filtered
                                }
                                if !code[idx].isEmpty {
                                    // переход к следующему полю
                                    focusedIndex = min(idx + 1, 3)
                                }
                            })
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .frame(width: 52, height: 56)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15), lineWidth: 1))
                        .focused($focusedIndex, equals: idx)
                    }
                }

                Button {
                    // Простая проверка: 4 цифры
                    if code.joined().count == 4 {
                        onVerified()
                    }
                } label: {
                    Text("Подтвердить")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(code.joined().count == 4 ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .blue.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .disabled(code.joined().count != 4)
                .padding(.horizontal)

                Button("Изменить номер/почту") {
                    onCancel()
                }
                .foregroundStyle(.white.opacity(0.8))

                Spacer()
            }
        }
        .onAppear { focusedIndex = 0 }
    }
}
