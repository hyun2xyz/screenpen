import Foundation

enum AppResources {
    private static let resourceBundleName = "ScreenPen_ScreenPen.bundle"

    static func url(
        forResource name: String,
        withExtension fileExtension: String,
        subdirectory: String
    ) -> URL? {
        let fileName = "\(name).\(fileExtension)"
        let fileManager = FileManager.default

        for root in candidateRoots() {
            let candidate = root
                .appendingPathComponent(resourceBundleName, isDirectory: true)
                .appendingPathComponent(subdirectory, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)

            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private static func candidateRoots() -> [URL] {
        var roots: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            roots.append(resourceURL)
        }

        roots.append(Bundle.main.bundleURL)

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            roots.append(executableDirectory)
        }

        var seenPaths = Set<String>()
        return roots.filter { seenPaths.insert($0.standardizedFileURL.path).inserted }
    }
}
