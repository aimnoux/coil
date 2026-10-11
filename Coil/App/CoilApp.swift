import SwiftUI

@main
struct CoilApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "circle.dashed",
                description: Text("Coil is under construction.")
            )
            .navigationTitle("Habits")
        }
    }
}

#Preview {
    ContentView()
}
