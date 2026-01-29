import SwiftUI

struct ChatSheetView: View {
    @StateObject private var chat = ChatLocalService()
    @State private var input: String = ""
    @State private var isLoading = false
    let initialContext: [String: String]

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
                        Task { await send() }
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
            }
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoading = true
        input = ""
        defer { isLoading = false }
        _ = await chat.ask(text, context: initialContext)
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

