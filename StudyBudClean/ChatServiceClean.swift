import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ChatServiceError: Error {
    case notSignedIn
    case threadNotFound
}

final class ChatServiceClean {
    static let shared = ChatServiceClean()
    private init() {}

    private var db: Firestore { Firestore.firestore() }

    /// Creates a new thread and makes the current user a member.
    /// Returns the new threadId.
    func createThread(name: String, isPublic: Bool = false,
                      completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(ChatServiceError.notSignedIn)); return
        }

        let threadRef = db.collection("threads").document()
        let threadData: [String: Any] = [
            "name": name,
            "type": isPublic ? "public" : "private",
            "createdBy": uid,
            "createdAt": FieldValue.serverTimestamp(),
            "lastMessagePreview": "",
            "lastMessageAt": FieldValue.serverTimestamp()
        ]

        // Write thread + membership in a single batch.
        let batch = db.batch()
        batch.setData(threadData, forDocument: threadRef)

        let memberRef = threadRef.collection("members").document(uid)
        batch.setData([
            "role": "member",
            "joinedAt": FieldValue.serverTimestamp()
        ], forDocument: memberRef)

        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(threadRef.documentID))
            }
        }
    }

    /// Sends a (plaintext) message to an existing thread.
    /// (We’ll replace body with ciphertext when we add E2E.)
    func sendMessage(threadId: String, text: String,
                     completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(ChatServiceError.notSignedIn)); return
        }

        let msgRef = db.collection("threads").document(threadId)
            .collection("messages").document()

        let data: [String: Any] = [
            "senderId": uid,
            "body": text,                    // TODO: replace with ciphertext
            "scheme": "plain-v0",            // TODO: update when encrypted
            "sentAt": FieldValue.serverTimestamp()
        ]

        // Also update thread's lastMessage* metadata in a batch
        let threadRef = db.collection("threads").document(threadId)
        let batch = db.batch()
        batch.setData(data, forDocument: msgRef)
        batch.updateData([
            "lastMessagePreview": String(text.prefix(80)),
            "lastMessageAt": FieldValue.serverTimestamp()
        ], forDocument: threadRef)

        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
