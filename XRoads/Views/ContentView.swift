import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "arrow.triangle.branch")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("XRoads")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .padding()
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
