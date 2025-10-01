import SwiftUI
import FirebaseFirestore

struct UserListView: View {
    @State private var users: [AppUser] = []
    @State private var loading = true

    var body: some View {
        NavigationView {
            List(users) { user in
                NavigationLink(destination: ChatView(user: user)) {
                    Text(user.email)
                        .font(.system(size: 18, weight: .medium))
                        .padding(.vertical, 6)
                }
            }
            .navigationTitle("Users")
            .onAppear {
                fetchUsers()
            }
        }
    }

    private func fetchUsers() {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }

            self.users = snapshot?.documents.compactMap { doc in
                try? doc.data(as: AppUser.self)
            } ?? []

            self.loading = false
        }
    }
}
