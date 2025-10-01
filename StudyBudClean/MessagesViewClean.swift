import SwiftUI
import FirebaseFirestore

// MARK: - Models

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let body: String        // UI uses `body`; Firestore stores this under key "text"
    let sentAt: Date
}

// MARK: - View

struct MessagesViewClean: View {
    let threadId: String

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var listener: ListenerRegistration?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            List(messages) { m in
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.body)
                    Text(m.sentAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)

            Divider()

            // Composer
            HStack(spacing: 8) {
                TextField("Type a message", text: $input)
                    .textFieldStyle(.roundedBorder)

                Button {
                    send()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { attachListener() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    // MARK: - Firestore listeners

    private func attachListener() {
        let db = Firestore.firestore()

        listener = db.collection("threads")
            .document(threadId)
            .collection("messages")
            .order(by: "sentAt")
            .limit(toLast: 50)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else { return }

                let newMessages: [ChatMessage] = docs.compactMap { d in
                    let data = d.data()

                    // 🔑 Firestore keys: "text", "senderId", "sentAt"
                    let text = data["text"] as? String ?? "" // <- map to UI `body`
                    let sender = data["senderId"] as? String ?? "?"
                    let sentAt = (data["sentAt"] as? Timestamp)?.dateValue() ?? Date.distantPast

                    return ChatMessage(
                        id: d.documentID,
                        senderId: sender,
                        body: text,
                        sentAt: sentAt
                    )
                }

                // Always update UI on the main queue
                DispatchQueue.main.async {
                    self.messages = newMessages
                }
            }
    }

    // MARK: - Sending

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""

        // Listener will update the list; we can ignore the result here.
        ChatServiceClean.shared.sendMessage(threadId: threadId, text: text) { _ in }
    }
}

