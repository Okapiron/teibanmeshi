import SwiftData
import SwiftUI

@main
struct TeibanMeshiApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Shop.self, OrderSet.self])
    }
}
