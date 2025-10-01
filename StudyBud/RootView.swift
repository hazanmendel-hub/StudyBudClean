import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        Group {
            if auth.user == nil {
                // If no user signed in, show Auth screen
                AuthView()
            } else {
                // If signed in, show User List screen
                UserListView()
            }
        }
    }
}

#Preview {
    RootView().environmentObject(AuthManager())
}
