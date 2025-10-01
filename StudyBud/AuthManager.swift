import Foundation
import Combine
import FirebaseAuth

/// Holds the signed-in user and updates automatically when auth state changes.
final class AuthManager: ObservableObject {
    @Published var user: FirebaseAuth.User?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        // Seed with current user (if any)
        self.user = Auth.auth().currentUser

        // Listen for future sign-in / sign-out changes
        self.handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
