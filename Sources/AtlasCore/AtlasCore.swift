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
        if let existingCredentials = Credentials.retrieve(baseDirectory).first {
            credentials.sync(existingCredentials)
        }

        if credentials.token == nil {
            if let token = GitHub.getAuthenticationToken(credentials) {
                credentials.setAuthenticationToken(token: token)
            }
        }
        
        guard credentials.token != nil else {
            print("No valid token found.")
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
                if !gitHub.setRepositoryLink() {
                    print("Failed to set repository link.")
                    return false
                }

                return true
            }
            return true
        }
        print("Failed to create Git repository.")
        return false
    }
    
    public func createGitRepository(_ credentials: Credentials) -> Bool {
        guard atlasDirectory != nil else {
            print("Trying to create Git repository but Atlas directory not available.")
            return false
        }
        
        let readme = atlasDirectory!.appendingPathComponent("readme.md", isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try "Welcome to Atlas".write(to: readme, atomically: true, encoding: .utf8)
            } catch {
                print("Unable to write Atlas readme.md")
                return false
            }
            
            _ = git!.runInit()
            commitChanges("Atlas Commit (Atlas Initialization)")
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
    
    public func startProject(_ name: String) -> Bool {
        guard atlasDirectory != nil else {
            return false
        }
        
        if !Project.exists(name, in: atlasDirectory!) {
            _ = Project(name, baseDirectory: atlasDirectory!)
            commitChanges("Atlas Commit (\(name) Project Initialization")
        }        
        
        return true
    }
    
    public func copy(_ filePath: String, into project: String) {
        guard atlasDirectory != nil else {
            return
        }
        
        let projectDirectory = atlasDirectory!.appendingPathComponent(project)
        _ = Glue.runProcess("cp", arguments: [filePath, projectDirectory.path])
    }
    
    public func commitChanges(_ commitMessage: String?=nil) {
        _ = git?.add()
        _ = git?.commit(commitMessage)
        _ = git?.pushToGitHub()
    }
    
    public func status() -> String? {
        guard git != nil else {
            return nil
        }
        
        return git.status()
    }
}
