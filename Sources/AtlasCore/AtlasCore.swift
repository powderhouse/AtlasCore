import Foundation

public class AtlasCore {
    
    public let repositoryName = "Atlas"
    public var baseDirectory: URL!
    public var atlasDirectory: URL!
    var git: Git!
    var gitHub: GitHub!
    
    
    public init(_ baseDirectory: URL?=nil) {
        self.baseDirectory = baseDirectory
        if baseDirectory == nil {
            self.baseDirectory = getDefaultBaseDirectory()
        }
        FileSystem.createDirectory(self.baseDirectory)
        
        if let credentials = getCredentials() {
            self.git = Git(self.baseDirectory)
            self.gitHub = GitHub(credentials, repositoryName: repositoryName, git: git)
            setAtlasDirectory(credentials)
            gitHub.setRepositoryLink()
        }
    }
    
    public func getDefaultBaseDirectory() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0])
    }
    
    public func setAtlasDirectory(_ credentials: Credentials?=nil) {
        var activeCredentials = credentials
        if activeCredentials == nil {
            activeCredentials = getCredentials()
        }
        
        guard activeCredentials != nil else {
            return
        }
        
        if let username = activeCredentials?.username {
            let userDirectory = baseDirectory.appendingPathComponent(username)
            self.atlasDirectory = userDirectory.appendingPathComponent(repositoryName)
            FileSystem.createDirectory(atlasDirectory)
        }
    }

    public func getCredentials() -> Credentials? {
        return Credentials.process(baseDirectory).first
    }
    
    public func initializeGit(_ credentials: Credentials) {
        self.git = Git(baseDirectory)
        setAtlasDirectory(credentials)
        self.gitHub = GitHub(credentials, repositoryName: repositoryName, git: git)
    }
    
    public func createGitRepository(_ credentials: Credentials) -> Bool {
        let readme = atlasDirectory.appendingPathComponent("readme.md", isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try "Welcome to Atlas".write(to: readme, atomically: true, encoding: .utf8)
            } catch {}
            
            _ = git!.runInit()
        }
        
        return true
    }
    
    public func gitHubRepository() -> String? {
        return gitHub.repositoryLink
    }
    
    public func createBaseDirectory() {
        FileSystem.createDirectory(baseDirectory)
    }
    
    public func deleteBaseDirectory() {
        FileSystem.deleteDirectory(baseDirectory)
    }
}
