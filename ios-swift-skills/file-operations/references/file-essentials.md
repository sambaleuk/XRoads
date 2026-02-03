# File Operations avec FileManager

Guide complet des opérations fichiers et répertoires en Swift pour des applications comme Maestro.

## FileManager Basics

```swift
let fileManager = FileManager.default

// Chemins communs
let homeDirectory = fileManager.homeDirectoryForCurrentUser
let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
let temporaryDirectory = fileManager.temporaryDirectory
let currentDirectory = fileManager.currentDirectoryPath
```

## Vérifier l'Existence de Fichiers/Dossiers

```swift
let fileManager = FileManager.default
let filePath = "/path/to/file.txt"

// Vérifier existence
if fileManager.fileExists(atPath: filePath) {
    print("File exists")
}

// Vérifier si c'est un répertoire
var isDirectory: ObjCBool = false
if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory) {
    if isDirectory.boolValue {
        print("It's a directory")
    } else {
        print("It's a file")
    }
}
```

## Lire des Fichiers

### Lire Texte

```swift
// Synchrone
let filePath = "/path/to/file.txt"
if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
    print(content)
}

// Avec URL
let fileURL = URL(fileURLWithPath: filePath)
if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
    print(content)
}

// Async
func readFile(at path: String) async throws -> String {
    let url = URL(fileURLWithPath: path)
    return try String(contentsOf: url, encoding: .utf8)
}
```

### Lire Data (binaire)

```swift
let fileURL = URL(fileURLWithPath: "/path/to/file.bin")
if let data = try? Data(contentsOf: fileURL) {
    print("Read \(data.count) bytes")
}
```

### Lire JSON

```swift
struct Config: Codable {
    let repoPath: String
    let maxSessions: Int
}

let fileURL = URL(fileURLWithPath: "/path/to/config.json")
let data = try Data(contentsOf: fileURL)
let config = try JSONDecoder().decode(Config.self, from: data)
```

## Écrire des Fichiers

### Écrire Texte

```swift
let content = "Hello, World!"
let filePath = "/path/to/file.txt"

// Synchrone
try content.write(toFile: filePath, atomically: true, encoding: .utf8)

// Avec URL
let fileURL = URL(fileURLWithPath: filePath)
try content.write(to: fileURL, atomically: true, encoding: .utf8)

// Async
func writeFile(content: String, to path: String) async throws {
    let url = URL(fileURLWithPath: path)
    try content.write(to: url, atomically: true, encoding: .utf8)
}
```

### Écrire Data

```swift
let data = Data("Hello".utf8)
let fileURL = URL(fileURLWithPath: "/path/to/file.bin")
try data.write(to: fileURL)
```

### Écrire JSON

```swift
let config = Config(repoPath: "/Users/me/repo", maxSessions: 10)
let data = try JSONEncoder().encode(config)

let fileURL = URL(fileURLWithPath: "/path/to/config.json")
try data.write(to: fileURL)

// Avec pretty print
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let prettyData = try encoder.encode(config)
try prettyData.write(to: fileURL)
```

## Créer et Supprimer des Répertoires

### Créer Répertoire

```swift
let fileManager = FileManager.default
let directoryPath = "/path/to/new/directory"

// Créer un seul niveau
try fileManager.createDirectory(
    atPath: directoryPath,
    withIntermediateDirectories: false,
    attributes: nil
)

// Créer toute la hiérarchie (mkdir -p)
try fileManager.createDirectory(
    atPath: directoryPath,
    withIntermediateDirectories: true,
    attributes: nil
)

// Avec URL
let directoryURL = URL(fileURLWithPath: directoryPath)
try fileManager.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: true
)
```

### Supprimer Fichier/Répertoire

```swift
let fileManager = FileManager.default
let path = "/path/to/file-or-directory"

// Supprimer
try fileManager.removeItem(atPath: path)

// Avec URL
let url = URL(fileURLWithPath: path)
try fileManager.removeItem(at: url)
```

## Lister le Contenu d'un Répertoire

### Liste Simple

```swift
let fileManager = FileManager.default
let directoryPath = "/path/to/directory"

// Tous les fichiers (noms seulement)
let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
for item in contents {
    print(item)
}

// Avec URLs
let directoryURL = URL(fileURLWithPath: directoryPath)
let fileURLs = try fileManager.contentsOfDirectory(
    at: directoryURL,
    includingPropertiesForKeys: nil
)
for url in fileURLs {
    print(url.lastPathComponent)
}
```

### Liste Récursive avec Enumerator

```swift
let fileManager = FileManager.default
let directoryURL = URL(fileURLWithPath: "/path/to/directory")

guard let enumerator = fileManager.enumerator(
    at: directoryURL,
    includingPropertiesForKeys: [.isDirectoryKey],
    options: [.skipsHiddenFiles]
) else {
    return
}

for case let fileURL as URL in enumerator {
    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
    if resourceValues.isDirectory == true {
        print("Directory: \(fileURL.lastPathComponent)")
    } else {
        print("File: \(fileURL.lastPathComponent)")
    }
}
```

### Filtrer par Extension

```swift
let directoryURL = URL(fileURLWithPath: "/path/to/directory")
let fileURLs = try fileManager.contentsOfDirectory(
    at: directoryURL,
    includingPropertiesForKeys: nil
)

// Filtrer .swift files
let swiftFiles = fileURLs.filter { $0.pathExtension == "swift" }
for file in swiftFiles {
    print(file.lastPathComponent)
}
```

## Copier et Déplacer des Fichiers

### Copier

```swift
let fileManager = FileManager.default
let sourceURL = URL(fileURLWithPath: "/path/to/source.txt")
let destinationURL = URL(fileURLWithPath: "/path/to/destination.txt")

// Copier
try fileManager.copyItem(at: sourceURL, to: destinationURL)

// Copier répertoire (récursif)
let sourceDir = URL(fileURLWithPath: "/path/to/source-dir")
let destDir = URL(fileURLWithPath: "/path/to/dest-dir")
try fileManager.copyItem(at: sourceDir, to: destDir)
```

### Déplacer (Renommer)

```swift
let fileManager = FileManager.default
let sourceURL = URL(fileURLWithPath: "/path/to/old-name.txt")
let destinationURL = URL(fileURLWithPath: "/path/to/new-name.txt")

// Déplacer/Renommer
try fileManager.moveItem(at: sourceURL, to: destinationURL)
```

## Attributs de Fichiers

### Obtenir Attributs

```swift
let fileManager = FileManager.default
let filePath = "/path/to/file.txt"

let attributes = try fileManager.attributesOfItem(atPath: filePath)

// Taille
if let fileSize = attributes[.size] as? Int {
    print("Size: \(fileSize) bytes")
}

// Date de modification
if let modificationDate = attributes[.modificationDate] as? Date {
    print("Modified: \(modificationDate)")
}

// Date de création
if let creationDate = attributes[.creationDate] as? Date {
    print("Created: \(creationDate)")
}

// Permissions
if let permissions = attributes[.posixPermissions] as? Int {
    print("Permissions: \(String(permissions, radix: 8))")
}
```

### Obtenir Taille d'un Fichier

```swift
func fileSize(atPath path: String) -> Int64? {
    let fileManager = FileManager.default
    guard let attributes = try? fileManager.attributesOfItem(atPath: path),
          let size = attributes[.size] as? Int64 else {
        return nil
    }
    return size
}

// Avec URL et ResourceValues
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")
let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
if let fileSize = resourceValues.fileSize {
    print("Size: \(fileSize) bytes")
}
```

## Pattern Maestro: Session Directory Manager

### Session Directory Structure

```swift
actor SessionDirectoryManager {
    private let fileManager = FileManager.default
    private let baseDirectory: URL

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    // Create session directory structure
    // ~/maestro-sessions/
    //   ├── session-uuid-1/
    //   │   ├── worktree/
    //   │   ├── logs/
    //   │   └── metadata.json
    //   ├── session-uuid-2/
    //   └── ...

    func createSessionDirectory(sessionId: UUID) async throws -> URL {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString)

        // Create directories
        try fileManager.createDirectory(
            at: sessionDir,
            withIntermediateDirectories: true
        )

        let worktreeDir = sessionDir.appendingPathComponent("worktree")
        let logsDir = sessionDir.appendingPathComponent("logs")

        try fileManager.createDirectory(at: worktreeDir, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: false)

        // Create metadata.json
        let metadata = SessionMetadata(
            id: sessionId,
            createdAt: Date(),
            status: .created
        )

        let metadataURL = sessionDir.appendingPathComponent("metadata.json")
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)

        return sessionDir
    }

    func deleteSessionDirectory(sessionId: UUID) async throws {
        let sessionDir = baseDirectory.appendingPathComponent(sessionId.uuidString)
        try fileManager.removeItem(at: sessionDir)
    }

    func listAllSessions() async throws -> [UUID] {
        let contents = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        return contents.compactMap { url in
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true,
                  let uuid = UUID(uuidString: url.lastPathComponent) else {
                return nil
            }
            return uuid
        }
    }

    func sessionDirectory(for sessionId: UUID) -> URL {
        baseDirectory.appendingPathComponent(sessionId.uuidString)
    }

    func worktreeDirectory(for sessionId: UUID) -> URL {
        sessionDirectory(for: sessionId).appendingPathComponent("worktree")
    }

    func logsDirectory(for sessionId: UUID) -> URL {
        sessionDirectory(for: sessionId).appendingPathComponent("logs")
    }
}

struct SessionMetadata: Codable {
    let id: UUID
    let createdAt: Date
    var status: SessionStatus
}

enum SessionStatus: String, Codable {
    case created
    case running
    case stopped
    case error
}
```

### Logs Manager

```swift
actor LogsManager {
    private let fileManager = FileManager.default
    private let logsDirectory: URL

    init(sessionId: UUID, directoryManager: SessionDirectoryManager) {
        self.logsDirectory = directoryManager.logsDirectory(for: sessionId)
    }

    func appendLog(_ message: String, to logFile: String = "output.log") async throws {
        let logURL = logsDirectory.appendingPathComponent(logFile)

        // Create log file if doesn't exist
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil)
        }

        // Append message
        let fileHandle = try FileHandle(forWritingTo: logURL)
        defer { try? fileHandle.close() }

        fileHandle.seekToEndOfFile()

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        if let data = logLine.data(using: .utf8) {
            fileHandle.write(data)
        }
    }

    func readLogs(from logFile: String = "output.log") async throws -> String {
        let logURL = logsDirectory.appendingPathComponent(logFile)
        return try String(contentsOf: logURL, encoding: .utf8)
    }

    func clearLogs(logFile: String = "output.log") async throws {
        let logURL = logsDirectory.appendingPathComponent(logFile)
        try "".write(to: logURL, atomically: true, encoding: .utf8)
    }

    func rotateLogs(logFile: String = "output.log", maxSize: Int = 10_000_000) async throws {
        let logURL = logsDirectory.appendingPathComponent(logFile)

        guard let attributes = try? fileManager.attributesOfItem(atPath: logURL.path),
              let size = attributes[.size] as? Int,
              size > maxSize else {
            return
        }

        // Rotate: output.log -> output.1.log -> output.2.log -> ...
        let timestamp = Int(Date().timeIntervalSince1970)
        let rotatedURL = logsDirectory.appendingPathComponent("output.\(timestamp).log")

        try fileManager.moveItem(at: logURL, to: rotatedURL)

        // Create new empty log
        fileManager.createFile(atPath: logURL.path, contents: nil)
    }
}
```

### Config File Manager

```swift
actor ConfigManager {
    private let fileManager = FileManager.default
    private let configURL: URL

    init(configPath: String = "~/.maestro/config.json") {
        let expandedPath = NSString(string: configPath).expandingTildeInPath
        self.configURL = URL(fileURLWithPath: expandedPath)
    }

    func loadConfig() async throws -> MaestroConfig {
        guard fileManager.fileExists(atPath: configURL.path) else {
            // Return default config
            return MaestroConfig.default
        }

        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(MaestroConfig.self, from: data)
    }

    func saveConfig(_ config: MaestroConfig) async throws {
        // Create directory if needed
        let directory = configURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        try data.write(to: configURL, options: .atomic)
    }

    func updateConfig(_ update: (inout MaestroConfig) -> Void) async throws {
        var config = try await loadConfig()
        update(&config)
        try await saveConfig(config)
    }
}

struct MaestroConfig: Codable {
    var sessionsDirectory: String
    var maxSessions: Int
    var defaultRepoPath: String?
    var claudePath: String

    static let `default` = MaestroConfig(
        sessionsDirectory: "~/maestro-sessions",
        maxSessions: 10,
        defaultRepoPath: nil,
        claudePath: "/usr/local/bin/claude"
    )
}
```

## Surveiller les Changements de Fichiers (File Watching)

### Avec DispatchSource

```swift
class FileWatcher {
    private let fileDescriptor: Int32
    private let source: DispatchSourceFileSystemObject
    private let queue = DispatchQueue(label: "file.watcher")

    init(path: String, onChange: @escaping () -> Void) throws {
        // Open file
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            throw FileWatcherError.cannotOpenFile
        }

        // Create dispatch source
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )

        // Set handler
        source.setEventHandler {
            onChange()
        }

        // Set cancel handler
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.fileDescriptor)
        }

        // Start watching
        source.resume()
    }

    deinit {
        source.cancel()
    }
}

enum FileWatcherError: Error {
    case cannotOpenFile
}

// Usage
let watcher = try FileWatcher(path: "/path/to/file.txt") {
    print("File changed!")
}
```

## Permissions et Sandbox

### Vérifier les Permissions

```swift
let fileManager = FileManager.default
let filePath = "/path/to/file.txt"

// Vérifier si readable
if fileManager.isReadableFile(atPath: filePath) {
    print("Can read")
}

// Vérifier si writable
if fileManager.isWritableFile(atPath: filePath) {
    print("Can write")
}

// Vérifier si deletable
if fileManager.isDeletableFile(atPath: filePath) {
    print("Can delete")
}

// Vérifier si executable
if fileManager.isExecutableFile(atPath: filePath) {
    print("Can execute")
}
```

### Bookmarks (macOS Sandbox)

```swift
// Create bookmark (save access to file)
let fileURL = URL(fileURLWithPath: "/path/to/file.txt")
let bookmarkData = try fileURL.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

// Save bookmarkData (e.g., UserDefaults)
UserDefaults.standard.set(bookmarkData, forKey: "fileBookmark")

// Later: restore access
guard let bookmarkData = UserDefaults.standard.data(forKey: "fileBookmark") else {
    return
}

var isStale = false
let url = try URL(
    resolvingBookmarkData: bookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)

// Start accessing
guard url.startAccessingSecurityScopedResource() else {
    throw FileError.accessDenied
}
defer {
    url.stopAccessingSecurityScopedResource()
}

// Now can access the file
let content = try String(contentsOf: url)
```

## Temporary Files

### Créer un Fichier Temporaire

```swift
let fileManager = FileManager.default
let tempDirectory = fileManager.temporaryDirectory

// Create unique temp file
let tempFileName = UUID().uuidString + ".txt"
let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)

// Write to temp file
try "Hello, temp!".write(to: tempFileURL, atomically: true, encoding: .utf8)

// Use temp file...

// Clean up
try fileManager.removeItem(at: tempFileURL)
```

### Temporary Directory pour une Session

```swift
func createTempSessionDirectory() throws -> URL {
    let fileManager = FileManager.default
    let tempDirectory = fileManager.temporaryDirectory

    let sessionDir = tempDirectory.appendingPathComponent(UUID().uuidString)
    try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)

    return sessionDir
}

// Usage
let tempDir = try createTempSessionDirectory()
// Work in tempDir...
// Clean up when done
try fileManager.removeItem(at: tempDir)
```

## Best Practices

### 1. Toujours utiliser URL plutôt que String

```swift
// ✅ Bon
let url = URL(fileURLWithPath: "/path/to/file.txt")
try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

// ❌ Moins bon
let path = "/path/to/file.txt"
try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
```

### 2. Gérer les erreurs

```swift
// ✅ Bon
do {
    let content = try String(contentsOf: fileURL)
} catch {
    print("Failed to read file: \(error)")
}

// ❌ Mauvais
let content = try! String(contentsOf: fileURL)  // Crash si erreur
```

### 3. Utiliser async pour les I/O

```swift
// ✅ Bon - non bloquant
func readFile(at url: URL) async throws -> String {
    try String(contentsOf: url)
}

// Usage
Task {
    let content = await readFile(at: url)
}
```

### 4. Nettoyer les ressources

```swift
// ✅ Bon
func processFile(at url: URL) throws {
    let fileHandle = try FileHandle(forReadingFrom: url)
    defer {
        try? fileHandle.close()  // Toujours fermer
    }

    // Use fileHandle...
}
```

### 5. Utiliser withIntermediateDirectories

```swift
// ✅ Bon - crée toute la hiérarchie
try fileManager.createDirectory(
    at: url,
    withIntermediateDirectories: true
)
```

## Erreurs Courantes

```swift
enum FileOperationError: Error {
    case fileNotFound(String)
    case accessDenied(String)
    case directoryNotEmpty(String)
    case invalidPath(String)
    case operationFailed(String)
}
```

## Résumé

✅ **FileManager** pour toutes les opérations fichiers
✅ **URL** plutôt que String pour les chemins
✅ **async** pour les I/O non bloquantes
✅ **try/catch** pour gérer les erreurs
✅ **withIntermediateDirectories: true** pour créer les hiérarchies
✅ **defer** pour nettoyer les ressources
✅ **Bookmarks** pour persister l'accès (sandbox)
✅ **DispatchSource** pour surveiller les fichiers
✅ **Actors** pour thread-safety dans les managers
