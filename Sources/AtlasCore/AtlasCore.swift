import Foundation

public struct File {
    public var name: String
    public var url: String
}

public struct Commit {
    public var message: String
    public var hash: String
    public var files: [File] = []
    public var projects: [Project] = []
}


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
            if gitHub.setPostCommitHook() {
                if !gitHub.setRepositoryLink() {
                    _ = gitHub.createRepository()
                    if !gitHub.setRepositoryLink() {
                        print("Failed to set repository link.")
                        return false
                    }

                    return true
                }
                return true
            } else {
                print("Failed to create post commit hooks")
                return false
            }
        }
        print("Failed to create Git repository.")
        return false
    }
    
    public func initGitRepository(_ credentials: Credentials) -> Bool {
        guard atlasDirectory != nil else {
            print("Trying to create Git repository but Atlas directory not available.")
            return false
        }
        
        let readme = atlasDirectory!.appendingPathComponent(Project.readme, isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try "Welcome to Atlas".write(to: readme, atomically: true, encoding: .utf8)
            } catch {
                print("Unable to write Atlas \(Project.readme)")
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
    
    public func projects() -> [Project] {
        guard atlasDirectory != nil else {
            return []
        }
        
        return git.projects().map { project($0)! }
    }
    
    public func project(_ name: String) -> Project? {
        guard atlasDirectory != nil else {
            return nil
        }

        return Project(name, baseDirectory: atlasDirectory!)
    }
    
    public func log(projectName: String?=nil, full: Bool=false) -> [Commit] {
        guard git != nil else {
            return []
        }

        let logData =  git.log(projectName: projectName, full: full)
        
        var commits: [Commit] = []
        for data in logData {
            guard data["hash"] != nil else { continue }
            
            var files: [File] = []
            var projects: [Project] = []
            
            let hash = data["hash"] as! String
            
            if let fileInfo = data["files"] as? [String] {
                for filePath in fileInfo {
                    if let repositoryLink = gitHub.repositoryLink {
                        let rawGitHub = repositoryLink.replacingOccurrences(
                            of: "github.com",
                            with: "raw.githubusercontent.com"
                        )
                        
                        let fileComponents = filePath.components(separatedBy: "/")
                        let fileName = String(fileComponents.last!)
                        files.append(File(name: fileName, url: "\(rawGitHub)/\(hash)/\(filePath)"))
                        
                        let projectName = String(fileComponents.first!)
                        projects.append(Project(projectName, baseDirectory: atlasDirectory!))
                    }
                }
            }
            
            if let message = data["message"] as? String {
                commits.append(Commit(message: message, hash: hash, files: files, projects: projects))
            }
        }
        return commits
    }
    
    public func purge(_ filePaths: [String]) -> Bool {
        guard git != nil && atlasDirectory != nil else {
            return false
        }
        
        var success = true
        
        var directories: [String] = []
        for filePath in filePaths {
            if !git!.removeFile(filePath) {
                success = false
            } else {
                let directory = URL(fileURLWithPath: filePath).deletingLastPathComponent().relativePath
                if !directories.contains(directory) {
                    directories.append(directory)
                }
            }
        }
        
        for directory in directories {
            if directory.contains("committed") {
                let fullDirectory = atlasDirectory!.appendingPathComponent(directory)
                let files = FileSystem.filesInDirectory(fullDirectory)
                if files.count == 1 && files.first!.contains(Project.readme) {
                    if !git!.removeFile("\(directory)/\(Project.readme)") {
                        success = false
                    }
                }
            }
        }
        
        return success
    }
        
    public func commitChanges(_ commitMessage: String?=nil) {
        _ = git?.add()
        _ = git?.commit(commitMessage)
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
    
    public func remote() -> String? {
        guard git != nil else {
            return nil
        }
        
        return git.remote()
    }
    
    public func validRepository() -> Bool {
        return gitHub?.validRepository() ?? false
    }
}
