import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var status = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("🔐 Firebase Auth Test")
                .font(.largeTitle).bold()

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding(.horizontal)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("Sign Up") { signUp() }
                .buttonStyle(.borderedProminent)

            Button("Login") { login() }
                .buttonStyle(.bordered)

            Text(status)
                .foregroundColor(.gray)
                .padding()
        }
        .padding()
    }

    private func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                status = "❌ Sign Up Failed: \(error.localizedDescription)"
                return
            }
            guard let user = result?.user else { return }
            status = "✅ Signed up as \(user.email ?? "")"

            // Create / merge user profile in Firestore
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).setData([
                "email": user.email ?? "",
                "displayName": "",                 // we’ll add UI for this later
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true) { err in
                if let err = err {
                    print("⚠️ Firestore user profile error:", err)
                } else {
                    print("✅ Firestore user profile created/updated")
                }
            }
        }
    }

    private func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                status = "❌ Login Failed: \(error.localizedDescription)"
                return
            }
            if let user = result?.user {
                status = "✅ Logged in as \(user.email ?? "")"
            }
        }
    }
}

#Preview { AuthView() }
