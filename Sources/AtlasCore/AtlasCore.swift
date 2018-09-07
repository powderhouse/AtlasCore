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

public struct Result {
    public var success: Bool! = true
    public var log: ((_ message: String) -> Void)? = nil
    var silenceLog: Bool = false
    
    public var messages: [String]! = [] {
        didSet(modified) {
            guard !silenceLog else {
                return
            }
            
            if let log = log {
                for message in messages {
                    if !modified.contains(message) {
                        log(message)
                    }
                }
            }
        }
    }
    
    public var allMessages: String {
        get {
            return messages.joined(separator: "\n")
        }
    }
    
    init(success: Bool=true, messages:[String]=[], log: ((_ message: String) -> Void)?=nil) {
        self.success = success
        self.messages = messages
        self.log = log
    }
    
    mutating func mergeIn(_ result: Result) {
        if !result.success {
            success = false
        }
        
        if result.log != nil {
            silenceLog = true
        }
        
        messages.append(contentsOf: result.messages)
        silenceLog = false
    }
    
    mutating func add(_ message: String) {
        add([message])
    }
    
    mutating func add(_ messages: [String]) {
        for message in messages {
            self.messages.append(message)
        }
    }
}


public class AtlasCore {
    
    public static let version = "1.7.4"
    public static let defaultProjectName = "General"
    public static let appName = "Atlas"
    public static let repositoryName = "Atlas"
    public static let originName = "AtlasOrigin"
    
    public var baseDirectory: URL!
    public var userDirectory: URL?
    public var appDirectory: URL?
    public var git: Git?
    public var gitHub: GitHub!
    public var search: Search!
    
    let externalLog: ((_ message: String) -> Void)?
    
    public init(_ baseDirectory: URL?=nil, externalLog: ((_ message: String) -> Void)?=nil) {
        self.baseDirectory = baseDirectory
        self.externalLog = externalLog
        if baseDirectory == nil {
            self.baseDirectory = getDefaultBaseDirectory()
        }
    }
    
    public func initialize() -> Result {
        var result = Result(log: externalLog)
        
        let directoryResult = FileSystem.createDirectory(self.baseDirectory)
        result.mergeIn(directoryResult)
        
        if let credentials = getCredentials() {
            let initializationResult = initGitAndGitHub(credentials)
            result.mergeIn(initializationResult)
            if userDirectory != nil && Search.exists(userDirectory!) {
                let searchResult = initSearch()
                result.mergeIn(searchResult)
            }
        }
        
        return result
    }
    
    public func getDefaultBaseDirectory() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0]).appendingPathComponent(AtlasCore.appName)
    }
    
    public func setUserDirectory(_ credentials: Credentials?=nil) -> Result {
        var result = Result(log: externalLog)
        var activeCredentials = credentials
        if activeCredentials == nil {
            activeCredentials = getCredentials()
        }
        
        guard activeCredentials != nil else {
            result.success = false
            result.add("No credentials found or provided.")
            return result
        }
        
        if let username = activeCredentials?.username {
            self.userDirectory = baseDirectory.appendingPathComponent(username)
            if let userDirectory = self.userDirectory {
                if !FileSystem.fileExists(userDirectory, isDirectory: true) {
                    result.add("Creating user directory.")
                    let directoryResult = FileSystem.createDirectory(userDirectory)
                    result.mergeIn(directoryResult)
                }
            }
        }
        return result
    }
    
    public func getCredentials() -> Credentials? {
        return Credentials.retrieve(baseDirectory).first
    }
    
    public func deleteCredentials() -> Result {
        return Credentials.delete(baseDirectory)
    }
    
    public func initGitAndGitHub(_ credentials: Credentials) -> Result {
        var result = Result(log: externalLog)
        
        credentials.setDirectory(baseDirectory)
        
        result.add("Syncing credentials.")
        
        if let existingCredentials = Credentials.retrieve(baseDirectory).first {
            credentials.sync(existingCredentials)
        }
        
        let userDirectoryResult = setUserDirectory(credentials)
        result.mergeIn(userDirectoryResult)
        
        if credentials.token == nil && credentials.remotePath == nil {
            if credentials.password != nil {
                result.add("Retrieving GitHub token.")
                if let token = GitHub.getAuthenticationToken(credentials) {
                    credentials.setAuthenticationToken(token)
                }
            } else {
                if let repository = userDirectory?.appendingPathComponent(AtlasCore.originName) {
                    let localRepositoryResult = FileSystem.createDirectory(repository)
                    result.mergeIn(localRepositoryResult)
                    credentials.setRemotePath(repository.path)
                }
            }
        }
        
        guard credentials.token != nil || credentials.remotePath != nil else {
            result.success = false
            result.add("No valid token or remote path found.")
            return result
        }
        
        credentials.save()
        
        if git == nil {
            git = Git(self.userDirectory!, credentials: credentials)
        }
        
        if let gitResult = git?.initialize(result) {
            result.mergeIn(gitResult)
        }
        
        appDirectory = git?.directory
        
        if initGitRepository(credentials) {
            result.add("Initializing GitHub")
            self.gitHub = GitHub(credentials, repositoryName: AtlasCore.repositoryName, git: git)
            
//            result.mergeIn(gitHub.setPostCommitHook(result))
            if result.success {
                result.mergeIn(gitHub.setRepositoryLink())
                if !result.success {
                    result.success = true
                    result.mergeIn(gitHub.createRepository(result))
                    result.mergeIn(gitHub.setRepositoryLink())
                    if !result.success {
                        result.add("Failed to set repository link.")
                        return result
                    }
                    
                    result.mergeIn(atlasCommit())
                }
                return result
            } else {
                result.success = false
                result.add("Failed to create post commit hooks")
                return result
            }
        }
        result.success = false
        result.add("Failed to create Git repository.")
        return result
    }
    
    public func initGitRepository(_ credentials: Credentials) -> Bool {
        guard git?.directory != nil else {
            print("Trying to create Git repository but Atlas directory not available.")
            return false
        }
        
        let readme = git!.directory.appendingPathComponent(Project.readme, isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try "Welcome to Atlas".write(to: readme, atomically: true, encoding: .utf8)
            } catch {
                print("Unable to write Atlas \(Project.readme): \(error)")
                return false
            }
            
        }
        
        return true
    }
    
    public func initSearch() -> Result {
        var result = Result()
        guard search == nil else { return result }
        
        guard userDirectory != nil else {
            result.success = false
            result.add("User directory not found for search")
            return result
        }
        
        search = Search(userDirectory!)
        
        guard search != nil else {
            result.success = false
            result.add("Search is still nil after initialization")
            return result
        }
        
        for project in projects() {
            for file in project.allFileUrls() {
                if !search.add(file) {
                    result.success = false
                    result.add("Unable to add \(file) to search")
                    return result
                }
            }
        }
        return result
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
    
    public func s3Repository() -> String? {
        return git?.annexRoot.count == 0 ? nil : git?.annexRoot
    }
    
    public func createBaseDirectory() -> Result {
        return FileSystem.createDirectory(baseDirectory)
    }
    
    public func deleteBaseDirectory() -> Result {
        return FileSystem.deleteDirectory(baseDirectory)
    }
    
    public func initProject(_ name: String) -> Bool {
        guard git?.directory != nil else {
            return false
        }
        
        if !Project.exists(name, in: git!.directory!) {
            _ = Project(
                name,
                baseDirectory: git!.directory!,
                git: git!,
                search: search,
                externalLog: externalLog
            )
        }
        
        return true
    }
    
    public func projects() -> [Project] {
        guard git?.directory != nil else {
            return []
        }
        
        return git!.projects().map { project($0)! }
    }
    
    public func project(_ name: String) -> Project? {
        guard git?.directory != nil else {
            return nil
        }
        
        return Project(
            name,
            baseDirectory: git!.directory!,
            git: git!,
            search: search,
            externalLog: externalLog
        )
    }
    
    public func log(projectName: String?=nil, full: Bool=false, commitSlugFilter: [String]?=nil) -> [Commit] {
        guard git != nil else {
            return []
        }
        
        let logData =  git!.log(projectName: projectName, full: full, commitSlugFilter: commitSlugFilter)
        
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
                    files.append(File(name: fileName, url: "\(git!.annexRoot)/\(filePath)"))
                    
                    if let projectName = fileComponents.first {
                        if Project.exists(projectName, in: git!.directory!) {
                            let p = Project(
                                projectName,
                                baseDirectory: git!.directory!,
                                git: git!,
                                externalLog: externalLog
                            )
                            projects.append(p)
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
    
    public func purge(_ filePaths: [String]) -> Result {
        var result = Result(log: externalLog)
        
        guard git?.directory != nil else {
            result.success = false
            result.add("No git directory found for purge")
            return result
        }
        
        result.add("Removing all files.")
        var directories: [String] = []
        for filePath in filePaths {
            result.mergeIn(git!.removeFile(filePath, existingResult: result))
            if result.success {
                let directory = URL(fileURLWithPath: filePath).deletingLastPathComponent().relativePath
                if !directories.contains(directory) {
                    directories.append(directory)
                }
            }
        }
        
        result.add("Removing directories.")
        for directory in directories {
            if directory.contains("committed") {
                let fullDirectory = git!.directory!.appendingPathComponent(directory)
                let files = FileSystem.filesInDirectory(fullDirectory)
                if files.count == 1 && files.first!.contains(Project.readme) {
                    result.mergeIn(git!.removeFile("\(directory)/\(Project.readme)", existingResult: result))
                }
            }
        }
        
        _ = Glue.runProcess(".git/hooks/\(GitHub.postCommitScriptName)", currentDirectory: git!.directory!)
        
        return result
    }
    
    public func commitChanges(_ commitMessage: String?=nil) -> Result {
        var result = Result(log: externalLog)
        
        result.add("Checking git status")
        let maxTries = 5
        var tries = 0
        if let git = git {
            if var status = git.status() {
                while tries < maxTries && !(status.contains("Untracked files") || status.contains("Changes to be committed")) {
                    sleep(1)
                    status = git.status() ?? ""
                    tries += 1
                }
                
                result.add("Committing files")
                result.mergeIn(git.add())
                result.mergeIn(git.commit(commitMessage))
                result.mergeIn(git.sync(result))
            } else {
                result.success = false
                result.add("No status provided by git for committing.")
            }
        } else {
            result.success = false
            result.add("Git not found for committing.")
        }
        
        return result
    }
    
    public func atlasCommit(_ message: String?=nil) -> Result {
        var submessage = ""
        if message != nil {
            submessage = " (\(message!))"
        }
        return commitChanges("Atlas Commit\(submessage)")
    }
    
    public func status() -> String? {
        guard git != nil else {
            return nil
        }
        
        return git!.status()
    }
    
    public func remote() -> String? {
        guard git != nil else {
            return nil
        }
        
        return git!.remote()
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
