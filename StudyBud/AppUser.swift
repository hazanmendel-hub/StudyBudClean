import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
}
