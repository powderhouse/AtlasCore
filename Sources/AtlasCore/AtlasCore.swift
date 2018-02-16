import Foundation

public class AtlasCore {
    
    public let appName = "Atlas"
    public let repositoryName = "Atlas"
    public var baseDirectory: URL!
    public var userDirectory: URL?
    public var atlasDirectory: URL?
    var git: Git!
    var gitHub: GitHub!
    
    
    public init(_ baseDirectory: URL?=nil) {
        self.baseDirectory = baseDirectory
        if baseDirectory == nil {
            self.baseDirectory = getDefaultBaseDirectory()
        }
        FileSystem.createDirectory(self.baseDirectory)
        
        if let credentials = getCredentials() {
            _ = initGitAndGitHub(credentials)
        }
    }
    
    public func getDefaultBaseDirectory() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0]).appendingPathComponent(appName)
    }
    
    public func setAtlasDirectory() {
        guard userDirectory != nil else {
            return
        }
        
        self.atlasDirectory = userDirectory!.appendingPathComponent(repositoryName)
        FileSystem.createDirectory(self.atlasDirectory!)
    }

    public func setUserDirectory(_ credentials: Credentials?=nil) {
        var activeCredentials = credentials
        if activeCredentials == nil {
            activeCredentials = getCredentials()
        }
        
        guard activeCredentials != nil else {
            return
        }
        
        if let username = activeCredentials?.username {
            self.userDirectory = baseDirectory.appendingPathComponent(username)
            FileSystem.createDirectory(self.userDirectory!)
        }
    }

    public func getCredentials() -> Credentials? {
        return Credentials.retrieve(baseDirectory).first
    }
    
    public func initGitAndGitHub(_ credentials: Credentials) -> Bool {
        if credentials.token == nil {
            if let token = GitHub.getAuthenticationToken(credentials) {
                credentials.setAuthenticationToken(token: token)
            }
        }
        
        guard credentials.token != nil else {
            return false
        }

        credentials.save(baseDirectory!)

        setUserDirectory(credentials)
        setAtlasDirectory()
        self.git = Git(self.atlasDirectory!)
        
        if createGitRepository(credentials) {
            self.gitHub = GitHub(credentials, repositoryName: repositoryName, git: git)
            if !gitHub.setRepositoryLink() {
                _ = gitHub.createRepository()
                _ = gitHub.setRepositoryLink()

                return true
            }
            return false
        }
        return false
    }
    
    public func createGitRepository(_ credentials: Credentials) -> Bool {
        guard atlasDirectory != nil else {
            return false
        }
        
        let readme = atlasDirectory!.appendingPathComponent("readme.md", isDirectory: false)
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
