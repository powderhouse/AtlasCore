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
    
    public static let version = "1.1.7"
    public static let defaultProjectName = "General"

    public static let appName = "Atlas"
    public static let repositoryName = "Atlas"
    public var baseDirectory: URL!
    public var userDirectory: URL?
    public var atlasDirectory: URL?
    var git: Git!
    var gitHub: GitHub!
    public var search: Search!
    
    
    public init(_ baseDirectory: URL?=nil) {
        self.baseDirectory = baseDirectory
        if baseDirectory == nil {
            self.baseDirectory = getDefaultBaseDirectory()
        }
        FileSystem.createDirectory(self.baseDirectory)
        
        if let credentials = getCredentials() {
            _ = initGitAndGitHub(credentials)
            if userDirectory != nil && Search.exists(userDirectory!) {
                _ = initSearch()
            }
        }
        
    }
    
    public func getDefaultBaseDirectory() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0]).appendingPathComponent(AtlasCore.appName)
    }
    
    public func setAtlasDirectory() {
        guard userDirectory != nil else {
            return
        }
        
        self.atlasDirectory = userDirectory!.appendingPathComponent(AtlasCore.repositoryName)
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
        self.git = Git(self.atlasDirectory!, credentials: credentials)
        atlasCommit()
        
        if initGitRepository(credentials) {
            self.gitHub = GitHub(credentials, repositoryName: AtlasCore.repositoryName, git: git)
            if gitHub.setPostCommitHook() {
                if !gitHub.setRepositoryLink() {
                    _ = gitHub.createRepository()
                    if !gitHub.setRepositoryLink() {
                        print("Failed to set repository link.")
                        return false
                    }

                    atlasCommit()
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
            
        }
        
        return true
    }
    
    public func initSearch() -> Bool {
        guard search == nil else { return true }
        
        guard userDirectory != nil else { return false }
        
        search = Search(userDirectory!)
        
        guard search != nil else { return false }
        
        if true || search.documentCount() == 0 {
            for project in projects() {
                for file in project.allFileUrls() {
                    if !search.add(file) {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    public func closeSearch() {
        search?.close()
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
            _ = Project(name, baseDirectory: atlasDirectory!, git: git, search: search)
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

        return Project(name, baseDirectory: atlasDirectory!, git: git, search: search)
    }
    
    public func log(projectName: String?=nil, full: Bool=false, commitSlugFilter: [String]?=nil) -> [Commit] {
        guard git != nil else {
            return []
        }

        let logData =  git.log(projectName: projectName, full: full, commitSlugFilter: commitSlugFilter)
        
        var commits: [Commit] = []
        for data in logData {
            guard data["hash"] != nil else { continue }
            
            var files: [File] = []
            var projects: [Project] = []
            
            let hash = data["hash"] as! String
            
            if let fileInfo = data["files"] as? [String] {
                for filePath in fileInfo {
                    let fileComponents = filePath.components(separatedBy: "/")
                    let fileName = String(fileComponents.last!)
                    files.append(File(name: fileName, url: "\(git.annexRoot)/\(filePath)"))
                    
                    if let projectName = fileComponents.first {
                        if Project.exists(projectName, in: atlasDirectory!) {
                            projects.append(Project(projectName, baseDirectory: atlasDirectory!, git: git))
                        }
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

        _ = Glue.runProcess(".git/hooks/\(GitHub.postCommitScriptName)", currentDirectory: atlasDirectory!)
        
        return success
    }
        
    public func commitChanges(_ commitMessage: String?=nil) {
        let group = DispatchGroup()
        group.enter()
        
        DispatchQueue.global().async {
            if let status = self.git.status() {
                if !status.contains("up-to-date") {
                    _ = self.git?.add()
                    _ = self.git?.commit(commitMessage)
                    group.leave()

                }
            }
        }
        
        group.wait()
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
    
    public func syncLog() -> String? {
        if let logUrl = userDirectory?.appendingPathComponent(GitHub.log) {
            return try? String(contentsOf: logUrl, encoding: .utf8)
        }
        return nil
    }
    
    public func syncLogEntries() -> [String] {
        if let log = syncLog() {
            return log.components(separatedBy: "<STARTENTRY>")
        }
        return []
    }

    public func completedLogEntries() -> [String] {
        let logEntries = syncLogEntries()
        return logEntries.filter { $0.contains("</ENDENTRY>")}
    }

    public func sync() {
        let scriptUrl = gitHub.hooks().appendingPathComponent(GitHub.postCommitScriptName)
        _ = Glue.runProcessError("bash", arguments: [scriptUrl.path])
    }
}
