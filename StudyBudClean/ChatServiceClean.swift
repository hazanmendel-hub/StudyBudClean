import Foundation
import FirebaseAuth
import FirebaseFirestore

final class ChatServiceClean {
    static let shared = ChatServiceClean()
    private let db = Firestore.firestore()
    private init() {}

    // Create a new thread and enroll the current user as a member.
    // Also write the per-user mirror index: /user_threads/{uid}/threads/{threadId}
    func createThread(name: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }

        let threadRef = db.collection("threads").document()
        let now = Date()

        let batch = db.batch()

        // Threads/{id}
        batch.setData([
            "name": name,
            "type": "private",
            "createdAt": Timestamp(date: now),
            "createdBy": uid,
            "lastMessageAt": Timestamp(date: now),
            "lastMessagePreview": ""
        ], forDocument: threadRef)

        // Threads/{id}/members/{uid}
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

    // Send a message to an existing thread.
    // Updates thread metadata and the sender's mirror index row.
    func sendMessage(threadId: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }

        let now = Date()
        let threadRef = db.collection("threads").document(threadId)
        let messageRef = threadRef.collection("messages").document()

        // Use a transaction to append message + update thread metadata atomically
        db.runTransaction({ (txn, errorPointer) -> Any? in
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
}

