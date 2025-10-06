import Foundation
import FirebaseAuth
import FirebaseFirestore

final class ChatServiceClean {
    static let shared = ChatServiceClean()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Threads

    /// Create a new thread and enroll the current user as a member.
    /// Also writes the per-user mirror index: /user_threads/{uid}/threads/{threadId}
    func createThread(name: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }

        let threadRef = db.collection("threads").document()
        let now = Date()
        let batch = db.batch()

        // threads/{id}
        batch.setData([
            "name": name,
            "type": "private",
            "createdAt": Timestamp(date: now),
            "createdBy": uid,
            "lastMessageAt": Timestamp(date: now),
            "lastMessagePreview": ""
        ], forDocument: threadRef)

        // threads/{id}/members/{uid}
        let memberRef = threadRef.collection("members").document(uid)
        batch.setData([
            "joinedAt": Timestamp(date: now)
        ], forDocument: memberRef)

        // user_threads/{uid}/threads/{id}  (mirror index row for current user)
        let userIndexRef = db.collection("user_threads")
            .document(uid)
            .collection("threads")
            .document(threadRef.documentID)

        batch.setData([
            "name": name,
            "lastMessageAt": Timestamp(date: now),
            "lastMessagePreview": ""
        ], forDocument: userIndexRef, merge: true)

        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(threadRef.documentID))
            }
        }
    }

    // MARK: - Messages

    /// Send a message to an existing thread.
    /// Updates thread metadata and the sender's mirror index row.
    func sendMessage(threadId: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }

        let now = Date()
        let threadRef = db.collection("threads").document(threadId)
        let messageRef = threadRef.collection("messages").document()

        // Append message + update thread metadata atomically
        db.runTransaction({ (txn, _) -> Any? in
            txn.setData([
                "text": text,
                "senderId": uid,
                "sentAt": Timestamp(date: now)
            ], forDocument: messageRef)

            txn.updateData([
                "lastMessageAt": Timestamp(date: now),
                "lastMessagePreview": text
            ], forDocument: threadRef)

            return nil
        }) { (_, txError) in
            if let txError = txError {
                completion(.failure(txError))
                return
            }

            // After metadata update, mirror to the current user's index row.
            threadRef.getDocument { snap, _ in
                let name = (snap?.data()?["name"] as? String) ?? "Untitled"

                let indexRef = self.db.collection("user_threads")
                    .document(uid)
                    .collection("threads")
                    .document(threadId)

                indexRef.setData([
                    "name": name,
                    "lastMessageAt": Timestamp(date: now),
                    "lastMessagePreview": text
                ], merge: true) { err in
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }

    // MARK: - Membership

    /// Create (or update) the caller's membership doc at /threads/{id}/members/{uid}
    /// Also ensures the user's mirror index row exists for this thread WITHOUT reading the thread doc.
    /// (Non-members can't read threads under current rules, so we avoid a read here.)
    func joinThread(threadId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not signed in."])))
            return
        }
        guard !threadId.isEmpty else {
            completion(.failure(NSError(domain: "threads", code: 400,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid thread id."])))
            return
        }

        let now = Timestamp(date: Date())

        let memberRef = db.collection("threads").document(threadId)
            .collection("members").document(uid)

        let userIndexRef = db.collection("user_threads").document(uid)
            .collection("threads").document(threadId)

        // Write membership + a minimal index row without attempting to read thread data.
        let batch = db.batch()
        batch.setData(["joinedAt": now], forDocument: memberRef, merge: true)
        batch.setData([
            // Keep fields minimal; name can be populated later by other flows.
            "lastMessageAt": now
        ], forDocument: userIndexRef, merge: true)

        batch.commit { e in
            if let e = e { completion(.failure(e)) }
            else { completion(.success(())) }
        }
    }

    /// Delete the caller's membership doc from /threads/{id}/members/{uid}
    /// Also removes the user's mirror index row for this thread.
    func leaveThread(threadId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not signed in."])))
            return
        }
        guard !threadId.isEmpty else {
            completion(.failure(NSError(domain: "threads", code: 400,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid thread id."])))
            return
        }

        let memberRef = db.collection("threads").document(threadId)
            .collection("members").document(uid)

        let userIndexRef = db.collection("user_threads").document(uid)
            .collection("threads").document(threadId)

        let batch = db.batch()
        batch.deleteDocument(memberRef)
        batch.deleteDocument(userIndexRef)

        batch.commit { e in
            if let e = e { completion(.failure(e)) }
            else { completion(.success(())) }
        }
    }

    /// Convenience: check if the caller currently has a membership doc in this thread.
    /// Uses server source to avoid stale cache after leaving.
    func isMember(of threadId: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !threadId.isEmpty else {
            completion(false); return
        }
        
        let memberRef = db.collection("threads").document(threadId)
            .collection("members").document(uid)
        
        // Force a server read to avoid local cache showing stale membership
        memberRef.getDocument(source: .server) { snap, error in
            // On network error, prefer "false" so we don't auto-attach listeners or re-join by accident.
            guard error == nil else { completion(false); return }
            completion(snap?.exists == true)
        }
    }
}

