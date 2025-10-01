import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State private var status = "Signing in…"
    @State private var currentThreadId: String? = nil
    @State private var threadName: String = "Test Thread"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("🧪 Threads + Messages Smoke Test")
                    .font(.title2).bold()

                // Global navigation to your Threads list
                NavigationLink {
                    ThreadsListClean()
                } label: {
                    Label("Open Threads", systemImage: "list.bullet.rectangle.portrait")
                        .font(.headline)
                }

                Divider().padding(.vertical, 4)

                // Show current thread id (if any)
                if let tid = currentThreadId {
                    Text("Thread: \(tid)")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                }

                // Thread name field
                HStack {
                    Text("Name:")
                    TextField("Thread name", text: $threadName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // Actions
                HStack(spacing: 12) {
                    Button { createThread() } label: {
                        Label("Create Thread", systemImage: "plus.bubble")
                    }

                    Button { sendMessage() } label: {
                        Label("Send Message", systemImage: "paperplane.fill")
                    }
                    .disabled(currentThreadId == nil)
                }

                // Open Messages for the current thread
                if let tid = currentThreadId {
                    NavigationLink {
                        MessagesViewClean(threadId: tid)
                    } label: {
                        Label("Open Messages", systemImage: "bubble.left.and.text.bubble.fill")
                            .font(.headline)
                    }
                } else {
                    Label("Open Messages", systemImage: "bubble.left.and.text.bubble.fill")
                        .foregroundStyle(.secondary)
                        .opacity(0.5)
                }

                // Status
                Text(status)
                    .padding()
                    .multilineTextAlignment(.center)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)

                Spacer()
            }
            .padding()
            .onAppear { signIn() }
        }
    }

    // MARK: - Flows

    private func signIn() {
        AuthManagerClean.shared.signInIfNeeded { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    status = "❌ Auth failed: \(error.localizedDescription)"
                case .success(let uid):
                    status = "✅ Signed in as \(uid.prefix(8))…"
                }
            }
        }
    }

    private func createThread() {
        status = "🛠️ Creating thread…"
        ChatServiceClean.shared.createThread(name: threadName) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    status = "❌ createThread failed: \(error.localizedDescription)"
                case .success(let threadId):
                    currentThreadId = threadId
                    status = "✅ Thread created: \(threadId)\nYou’re a member."
                }
            }
        }
    }

    private func sendMessage() {
        guard let tid = currentThreadId else {
            status = "ℹ️ Create a thread first."
            return
        }
        status = "✉️ Sending message…"
        let text = "Hello at \(Date())"
        ChatServiceClean.shared.sendMessage(threadId: tid, text: text) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    status = "❌ sendMessage failed: \(error.localizedDescription)"
                case .success:
                    status = "✅ Message sent to \(tid)"
                }
            }
        }
    }
}

