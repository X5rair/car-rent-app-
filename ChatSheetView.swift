import SwiftUI

struct ChatSheetView: View {
    @StateObject private var chat = ChatLocalService()
    @State private var input: String = ""
    @State private var isLoading = false
    let initialContext: [String: String]

    // Новые параметры
    let starterQuestion: String?
    let quickQuestions: [String]

    // Настройка "размышления"
    // Минимальная задержка перед ответом, чтобы казалось, что помощник думает
    private let thinkingDelay: UInt64 = 700_000_000 // 0.7 сек

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(chat.messages) { msg in
                                bubble(for: msg)
                                    .id(msg.id)
                            }

                            // Быстрые вопросы под сообщениями
                            if !quickQuestions.isEmpty {
                                quickQuestionsView
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    .onChange(of: chat.messages.count) { _ in
                        if let last = chat.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Задайте вопрос…", text: $input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)
                    Button {
                        Task { await send(text: input) }
                    } label: {
                        if isLoading {
                            ProgressView().padding(.horizontal, 8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("ИИ‑помощник")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                chat.reset()
                chat.greetIfNeeded(context: initialContext)
                if let starter = starterQuestion, !starter.isEmpty {
                    Task { await send(text: starter) }
                }
            }
        }
    }

    private var quickQuestionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickQuestions, id: \.self) { q in
                    Button(q) {
                        Task { await send(text: q) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.15), in: Capsule())
                }
            }
        }
    }

    private func send(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        input = ""
        // “Размышление” — небольшая задержка перед ответом
        try? await Task.sleep(nanoseconds: thinkingDelay)
        defer { isLoading = false }
        _ = await chat.ask(trimmed, context: initialContext)
    }

    @ViewBuilder
    private func bubble(for msg: LocalChatMessage) -> some View {
        let isUser = msg.role == .user
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(msg.content)
                .padding(10)
                .background(isUser ? Color.blue.opacity(0.9) : Color.gray.opacity(0.2))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
