import Foundation

public struct Credentials {
    public let username: String
    public let password: String?
    public var token: String?
    
    public init(_ username: String, password: String?=nil, token: String?=nil) {
        self.username = username
        self.password = password
        self.token = token
    }
}

public class AtlasCore {
    
    public var baseDirectory: URL!
    var git: Git?
    
    public init(_ baseDirectory: URL?=nil) {
        self.baseDirectory = baseDirectory
        if baseDirectory == nil {
            self.baseDirectory = getDefaultBaseDirectory()
        }
        FileSystem.createDirectory(self.baseDirectory)
        
        if let credentials = getGitCredentials() {
            self.git = Git(self.baseDirectory, credentials: credentials)
            self.git?.setGitHubRepositoryLink()
        }
    }
    
    public func getDefaultBaseDirectory() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0]).appendingPathComponent("Atlas")
    }

    public func getGitCredentials() -> Credentials? {
        return Git.getCredentials(baseDirectory)
    }
    
    public func initGit(_ credentials: Credentials) -> Bool {
        self.git = Git(baseDirectory, credentials: credentials)
        
        guard self.git != nil else { return false }
        
        let readme = baseDirectory.appendingPathComponent("readme.md", isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try "Welcome to Atlas".write(to: readme, atomically: true, encoding: .utf8)
            } catch {}
            
            _ = git!.runInit()
            _ = git!.initGitHub()
        }
        
        return true
    }
    
    public func gitHubRepository() -> String? {
        return git?.githubRepositoryLink
    }
    
    public func createBaseDirectory() {
        FileSystem.createDirectory(baseDirectory)
    }
    
    public func deleteBaseDirectory() {
        FileSystem.deleteDirectory(baseDirectory)
    }
}
