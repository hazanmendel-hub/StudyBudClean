import SwiftUI
import FirebaseFirestore

// MARK: - Model

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let body: String        // Firestore key = "text"
    let sentAt: Date
}

// MARK: - View

struct MessagesViewClean: View {
    let threadId: String

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var listener: ListenerRegistration?

    @State private var isMember: Bool? = nil
    @State private var membershipBusy = false

    var body: some View {
        VStack(spacing: 0) {
            if isMember == false {
                // Banner shown when user is not a member
                Text("You’re not a member of this thread. Join to read & send messages.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }

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
                .disabled(!(isMember ?? false) ||
                          input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let member = isMember {
                    Button {
                        toggleMembership(isCurrentlyMember: member)
                    } label: {
                        HStack(spacing: 6) {
                            if membershipBusy { ProgressView() }
                            Text(member ? "Leave" : "Join")
                        }
                    }
                    .disabled(membershipBusy)
                } else {
                    ProgressView()
                }
            }
        }
        .onAppear {
            refreshMembership()
        }
        .onDisappear {
            detachListener()
        }
    }

    // MARK: - Membership

    private func refreshMembership() {
        ChatServiceClean.shared.isMember(of: threadId) { member in
            DispatchQueue.main.async {
                self.isMember = member
                if member {
                    self.attachListener()
                } else {
                    self.detachListener()
                    self.messages = []
                }
            }
        }
    }

    private func toggleMembership(isCurrentlyMember: Bool) {
        membershipBusy = true
        if isCurrentlyMember {
            ChatServiceClean.shared.leaveThread(threadId: threadId) { result in
                DispatchQueue.main.async {
                    self.membershipBusy = false
                    switch result {
                    case .success:
                        self.isMember = false
                        self.detachListener()
                        self.messages = []
                    case .failure:
                        // Keep UI state unchanged on failure
                        break
                    }
                }
            }
        } else {
            ChatServiceClean.shared.joinThread(threadId: threadId) { result in
                DispatchQueue.main.async {
                    self.membershipBusy = false
                    switch result {
                    case .success:
                        self.isMember = true
                        self.attachListener()
                    case .failure:
                        // Keep UI state unchanged on failure
                        break
                    }
                }
            }
        }
    }

    // MARK: - Firestore listeners

    private func attachListener() {
        detachListener() // avoid double listeners

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
                    let text = data["text"] as? String ?? ""          // 🔑 Firestore key
                    let sender = data["senderId"] as? String ?? "?"
                    let sentAt = (data["sentAt"] as? Timestamp)?.dateValue() ?? .distantPast

                    return ChatMessage(id: d.documentID,
                                       senderId: sender,
                                       body: text,
                                       sentAt: sentAt)
                }

                DispatchQueue.main.async {
                    self.messages = newMessages
                }
            }
    }

    private func detachListener() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Sending

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(text.isEmpty), isMember == true else { return }
        input = ""
        ChatServiceClean.shared.sendMessage(threadId: threadId, text: text) { _ in
            // no-op; listener will refresh
        }
    }
}

