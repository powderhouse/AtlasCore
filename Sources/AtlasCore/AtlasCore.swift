import Foundation

public class AtlasCore {
    
    var baseDirectory: URL!
//    var git: Git?
    
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

}
