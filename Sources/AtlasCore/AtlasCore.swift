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
    
    public func deleteCredentials() {
        Credentials.delete(baseDirectory)
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
        
        if initGitRepository(credentials) {
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
    
    public func initGitRepository(_ credentials: Credentials) -> Bool {
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
        }
        
        return true
    }
    
    public func deleteGitHubRepository() {
        guard gitHub != nil else {
            return
        }
        
        gitHub.deleteRepository()
    }
    
    public func gitHubRepository() -> String? {
        return gitHub?.repositoryLink
    }
    
    public func createBaseDirectory() {
        FileSystem.createDirectory(baseDirectory)
    }
    
    public func deleteBaseDirectory() {
        FileSystem.deleteDirectory(baseDirectory)
    }
    
    public func initProject(_ name: String) -> Bool {
        guard atlasDirectory != nil else {
            return false
        }
        
        if !Project.exists(name, in: atlasDirectory!) {
            _ = Project(name, baseDirectory: atlasDirectory!)
        }
        
        return true
    }
    
    public func project(_ name: String) -> Project? {
        guard atlasDirectory != nil else {
            return nil
        }

        return Project(name, baseDirectory: atlasDirectory!)
    }
    
    public func copy(_ filePaths: [String], into project: String) -> Bool {
        guard atlasDirectory != nil else {
            return false
        }
        
        let project = Project(project, baseDirectory: atlasDirectory!)
        return FileSystem.copy(filePaths, into: project.directory("staged"))
    }

    public func changeState(_ fileNames: [String], within project: String, to state: String) -> Bool {
        guard atlasDirectory != nil else {
            return false
        }

        let project = Project(project, baseDirectory: atlasDirectory!)
        var filePaths: [String] = []
        for fileName in fileNames {
            let fromState = state == "staged" ? "unstaged" : "staged"
            let file = project.directory(fromState).appendingPathComponent(fileName)
            filePaths.append(file.path)
        }
        return FileSystem.move(filePaths, into: project.directory(state))
    }
    
    public func commitChanges(_ commitMessage: String?=nil) {
        _ = git?.add()
        _ = git?.commit(commitMessage)
        _ = git?.pushToGitHub()
    }
    
    public func atlasCommit(_ message: String?=nil) {
        var submessage = ""
        if message != nil {
            submessage = " (\(message!))"
        }
        commitChanges("Atlas Commit\(submessage)")
    }
    
    public func status() -> String? {
        guard git != nil else {
            return nil
        }
        
        return git.status()
    }
}
