import SwiftUI
import FirebaseCore

@main
struct StudyBudCleanApp: App {
    init() {
        // Configure Firebase as early as possible
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
