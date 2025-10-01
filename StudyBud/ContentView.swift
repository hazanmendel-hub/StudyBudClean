import SwiftUI
import FirebaseFirestore

struct ContentView: View {
    @State private var status: String = "Running Firestore test..."

    var body: some View {
        VStack(spacing: 16) {
            Text("🔥 Firebase Test")
                .font(.largeTitle).bold()
            Text(status)
                .padding()
                .background(Color.yellow.opacity(0.25))
                .cornerRadius(8)
        }
        .padding()
        .onAppear { testFirestore() }
    }

    private func testFirestore() {
        let db = Firestore.firestore()
        let doc = db.collection("tests").document("hello")

        // Write
        doc.setData(["message": "Hello from StudyBud!"]) { error in
            if let error = error {
                status = "Write failed: \(error.localizedDescription)"
            } else {
                // Read back
                doc.getDocument { snapshot, error in
                    if let error = error {
                        status = "Read failed: \(error.localizedDescription)"
                    } else if let data = snapshot?.data(),
                              let msg = data["message"] as? String {
                        status = "Success ✅ Read: \(msg)"
                    } else {
                        status = "No data."
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
