import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ThreadItem: Identifiable, Equatable {
    let id: String
    let name: String
    let lastMessagePreview: String
    let lastMessageAt: Date
}

struct ThreadsListClean: View {
    @State private var items: [ThreadItem] = []
    @State private var membershipListener: ListenerRegistration?
    @State private var threadListeners: [String: ListenerRegistration] = [:]

    var body: some View {
        List(items.sorted(by: { $0.lastMessageAt > $1.lastMessageAt })) { item in
            NavigationLink {
                MessagesViewClean(threadId: item.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                    Text(item.lastMessagePreview)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Text(item.lastMessageAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Threads")
        .onAppear { attachMembershipListener() }
        .onDisappear { detachAllListeners() }
    }

    // MARK: - Listeners

    private func attachMembershipListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        // TEMP: listen to all /threads/*/members/*, then filter to docs where id == uid.
        // We'll add a /user_threads/{uid}/threads/{threadId} mirror later for efficient queries.
        membershipListener = db.collectionGroup("members")
            .addSnapshotListener { snapshot, error in
                guard let allDocs = snapshot?.documents, error == nil else { return }

                // Only memberships for the signed-in user
                let myMemberDocs = allDocs.filter { $0.documentID == uid }

                // Which thread IDs should we be listening to now?
                let currentThreadIds = Set(
                    myMemberDocs.compactMap { $0.reference.parent.parent?.documentID }
                )

                // Detach listeners for threads we no longer belong to
                for (tid, l) in threadListeners where !currentThreadIds.contains(tid) {
                    l.remove()
                    threadListeners.removeValue(forKey: tid)
                    items.removeAll { $0.id == tid }
                }

                // Attach listeners for any new threads
                for doc in myMemberDocs {
                    guard let threadRef = doc.reference.parent.parent else { continue }
                    let tid = threadRef.documentID

                    guard threadListeners[tid] == nil else { continue }
                    threadListeners[tid] = threadRef.addSnapshotListener { threadSnap, _ in
                        guard let data = threadSnap?.data() else { return }

                        let name = data["name"] as? String ?? "Untitled"
                        let preview = data["lastMessagePreview"] as? String ?? ""
                        let lastAt = (data["lastMessageAt"] as? Timestamp)?.dateValue()
                            ?? Date(timeIntervalSince1970: 0)

                        let item = ThreadItem(
                            id: tid,
                            name: name,
                            lastMessagePreview: preview,
                            lastMessageAt: lastAt
                        )

                        if let idx = items.firstIndex(where: { $0.id == tid }) {
                            items[idx] = item
                        } else {
                            items.append(item)
                        }
                    }
                }
            }
    }

    private func detachAllListeners() {
        membershipListener?.remove()
        membershipListener = nil
        threadListeners.values.forEach { $0.remove() }
        threadListeners.removeAll()
    }
}

