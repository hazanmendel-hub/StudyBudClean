import Foundation
import FirebaseAuth

final class AuthManagerClean {
    static let shared = AuthManagerClean()
    private init() {}

    /// Signs in anonymously if not already signed in.
    /// Calls completion with the current UID.
    func signInIfNeeded(completion: @escaping (Result<String, Error>) -> Void) {
        if let uid = Auth.auth().currentUser?.uid {
            completion(.success(uid))
            return
        }
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let uid = result?.user.uid {
                completion(.success(uid))
            } else {
                completion(.failure(NSError(domain: "Auth", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Unknown auth state"])))
            }
        }
    }
}
