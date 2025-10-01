import SwiftUI
import FirebaseFirestore

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let body: String
    let sentAt: Date
}

struct MessagesViewClean: View {
    let threadId: String

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var listener: ListenerRegistration?

    var body: some View {
        VStack(spacing: 0) {
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

            HStack(spacing: 8) {
                TextField("Type a message", text: $input)
                    .textFieldStyle(.roundedBorder)
                Button {
                    send()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(input.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { attachListener() }
        .onDisappear { listener?.remove() }
    }

    private func attachListener() {
        let db = Firestore.firestore()
        listener = db.collection("threads").document(threadId)
            .collection("messages")
            .order(by: "sentAt")
            .limit(toLast: 50)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else { return }
                messages = docs.compactMap { d in
                    let data = d.data()
                    let sender = data["senderId"] as? String ?? "?"
                    let body = data["body"] as? String ?? ""
                    let ts = (data["sentAt"] as? Timestamp)?.dateValue() ?? Date()
                    return ChatMessage(id: d.documentID, senderId: sender, body: body, sentAt: ts)
                }
            }
    }

    private func send() {
        let text = input
        input = ""
        ChatServiceClean.shared.sendMessage(threadId: threadId, text: text) { _ in
            // Ignore result for the demo; the listener will update the list.
        }
    }
}

