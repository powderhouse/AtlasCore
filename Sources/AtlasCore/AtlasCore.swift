import Foundation

public class AtlasCore {
    
    public var baseDirectory: URL!
    var git: Git?
    
    public init(_ baseDirectory: URL?=nil) {
        self.baseDirectory = baseDirectory
        if baseDirectory == nil {
            self.baseDirectory = getDefaultBaseDirectory()
        }
    }
    
    public func getDefaultBaseDirectory() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0]).appendingPathComponent("Atlas")
    }

    public func getGitCredentials() -> Credentials? {
        return Git.getCredentials(baseDirectory)
    }
    
    public func initGit(_ credentials: Credentials) {
        FileSystem.createDirectory(baseDirectory)
        self.git = Git(baseDirectory, credentials: credentials)
        
        guard self.git != nil else { return }
        
        let readme = baseDirectory.appendingPathComponent("readme.md", isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try "Welcome to Atlas".write(to: readme, atomically: true, encoding: .utf8)
            } catch {}
            
            _ = git!.runInit()
            _ = git!.initGitHub()
        }
        
    }
    
    public func createBaseDirectory() {
        FileSystem.createDirectory(baseDirectory)
    }
    
    public func deleteBaseDirectory() {
        FileSystem.deleteDirectory(baseDirectory)
    }
}
