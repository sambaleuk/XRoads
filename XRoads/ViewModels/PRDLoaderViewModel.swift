import Foundation

@MainActor
final class PRDLoaderViewModel: ObservableObject {

    @Published var selectedURL: URL?
    @Published var document: PRDDocument?
    @Published var errorMessage: String?

    private let parser = PRDParser()

    func load(url: URL) async {
        do {
            let doc = try await parser.parse(fileURL: url)
            selectedURL = url
            document = doc
            errorMessage = nil
        } catch {
            document = nil
            selectedURL = nil
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        selectedURL = nil
        document = nil
        errorMessage = nil
    }
}
