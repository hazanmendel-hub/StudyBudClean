import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// A simple struct to represent each chat message
struct Message: Identifiable {
    let id: String
    let text: String
    let senderId: String
    let createdAt: Date

    var isMine: Bool {
        senderId == Auth.auth().currentUser?.uid
    }
}

struct ChatView: View {
    @State private var input = ""
    @State private var messages: [Message] = []
    @State private var listener: ListenerRegistration?

    private var db: Firestore { Firestore.firestore() }
    private var messagesRef: CollectionReference {
        db.collection("chats").document("global").collection("messages")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("💬 Global Chat")
                    .font(.title2).bold()
                Spacer()
                Button("Sign out") {
                    try? Auth.auth().signOut()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            // Messages
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { msg in
                        HStack {
                            if msg.isMine { Spacer() }
                            Text(msg.text)
                                .padding(10)
                                .background(msg.isMine ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            if !msg.isMine { Spacer() }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // Input bar
            HStack {
                TextField("Type a message…", text: $input)
                    .textFieldStyle(.roundedBorder)
                Button("Send") { send() }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
    }

    // 🔹 Start listening to Firestore for new messages
    private func startListening() {
        listener = messagesRef
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥 listen error:", error.localizedDescription)
                    return
                }
                let docs = snapshot?.documents ?? []
                self.messages = docs.compactMap { doc in
                    let data = doc.data()
                    let text = data["text"] as? String ?? ""
                    let sender = data["senderId"] as? String ?? ""
                    let date = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    return Message(id: doc.documentID, text: text, senderId: sender, createdAt: date)
                }
            }
    }

    // 🔹 Stop listening when the view disappears
    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    // 🔹 Send a new message
    private func send() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messagesRef.addDocument(data: [
            "text": trimmed,
            "senderId": uid,
            "createdAt": FieldValue.serverTimestamp()
        ]) { err in
            if let err = err {
                print("🔥 send error:", err.localizedDescription)
            } else {
                input = ""
            }
        }
    }
}

#Preview { ChatView() }
