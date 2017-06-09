//
//  Project.swift
//  Refactorator
//
//  Created by John Holdsworth on 20/11/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

import Cocoa

let HOME = String( cString: getenv("HOME") )

class Project: NSObject {

    static var lastProject: Project?
    static var unknown = "unknown"

    var xCode: SBApplication?
    var workspaceDoc: SBObject?

    var workspacePath = unknown
    var projectRoot = unknown
    var derivedData = unknown
    var indexPath = unknown
    var indexDB: IndexDB?

    var entity: Entity?

    var workspaceName: String {
        return workspacePath.url.lastPathComponent
    }

    static func openWorkspace( workspaceDoc: SBObject?, workspacePath: String, relative: Bool ) throws -> (String, String, String, IndexDB?) {
        let workspaceURL = workspacePath.url
        let projectRoot = workspaceURL.deletingLastPathComponent().path
        let projectName = workspaceURL.deletingPathExtension().lastPathComponent
        let derivedData = (relative ? projectRoot.url.appendingPathComponent("DerivedData") :
            HOME.url.appendingPathComponent("Library/Developer/Xcode/DerivedData")).appendingPathComponent( projectName
                .replacingOccurrences(of: " ", with: "_") + (relative ? "" : "-" + Utils.hashString(forPath: workspacePath)) ).path

        var indexPaths = [String]()
        for config in try FileManager.default.contentsOfDirectory(atPath: derivedData+"/Index" ) {
            let configPath = "\(derivedData)/Index/\(config)"
            if configPath.url.hasDirectoryPath {
                for platformArch in try FileManager.default.contentsOfDirectory(atPath: configPath) {
                    indexPaths.append( "\(configPath)/\(platformArch)" )
                }
            }
        }

        let runDest = workspaceDoc?.activeRunDestination
        func makeIndexPath( _ indexPath: String ) -> String {
            return "\(indexPath)/\(projectName).xcindex/db.xcindexdb"
        }

        let platformArch = indexPaths.filter { $0.url.hasDirectoryPath && (runDest == nil ||
            ($0.contains(runDest!.platform) && $0.hasSuffix(runDest!.architecture))) }.sorted(by: {
            (a, b) in
            return mtime( makeIndexPath( a )+".strings-res" ) > mtime( makeIndexPath( b )+".strings-res" )
        } ).first

//        if platformArch == nil {
//            throw NSError(domain: "Could not find an index db", code: 0, userInfo: ["DerivedData":derivedData])
//        }

        let indexPath = platformArch != nil ? makeIndexPath( platformArch! ) : "notfound"
        return (projectRoot, derivedData, indexPath, IndexDB(dbPath: indexPath))
    }

    static func findProject(for target: Entity) -> String? {
        let manager = FileManager.default

        func fileWithExtension( ext: String, in dirURL: URL ) throws -> String? {
            for name in try manager.contentsOfDirectory(atPath: dirURL.path) {
                if name.url.pathExtension == ext {
                    return name
                }
            }
            return nil
        }

        print("findProject for: \(target.file)")
        for ext in ["xcworkspace", "xcodeproj"] {
            var potentialRoot = target.file.url.deletingLastPathComponent()
            do {
                while potentialRoot.path != "/" {
                    if let foundProject = try fileWithExtension(ext: ext, in: potentialRoot) {
                        return potentialRoot.appendingPathComponent(foundProject).path
                    }
                    potentialRoot.deleteLastPathComponent()
                }
            }
            catch {
                xcode.error("Could not list directory \(potentialRoot)")
            }
        }

        return nil
    }

    init(target: Entity?) {
        xCode = SBApplication(bundleIdentifier:"com.apple.dt.Xcode")
        IndexDB.projectDirs.removeAll()

        if let xCode = xCode {
            var workspaceDocs = [String:SBObject]()
            for workspace in xCode.workspaceDocuments().map( { $0 as! SBObject } ) {
                if let path = workspace.path {
                    workspaceDocs[path] = workspace
                }
            }

            let windows = xCode.windows().sorted(by: {
                return ($0 as! SBObject).index < ($1 as! SBObject).index
            }).filter { ($0 as! SBObject).document.path != nil }

            for window in windows {
                workspacePath = (window as! SBObject).document!.path
                workspaceDoc = workspaceDocs[workspacePath]
                do {
                    (projectRoot, derivedData, indexPath, indexDB) =
                        try Project.openWorkspace(workspaceDoc: workspaceDoc, workspacePath: workspacePath, relative: true)
                    if target != nil ? IndexDB.projectIncludes(file: target!.file) : true {
                        print("workspace: \(workspacePath)")
                        break
                    }
                }
                catch {
                    do {
                        (projectRoot, derivedData, indexPath, indexDB) =
                            try Project.openWorkspace(workspaceDoc: workspaceDoc, workspacePath: workspacePath, relative: false)
                        if target != nil ? IndexDB.projectIncludes(file: target!.file) : true {
                            print("workspace: \(workspacePath)")
                            break
                        }
                    }
                    catch (let e) {
                        xcode.log("Could not find indexDB for any open workspace docs \(e)")
                    }
                }
            }

            let relevantDoc = xCode.sourceDocuments().filter {
                let sourceDoc = $0 as! SBObject, ext = sourceDoc.path?.url.pathExtension
//                print("sourceDoc: \(sourceDoc.path!)")
                return IndexDB.projectIncludes(file: sourceDoc.path) && sourceDoc.selectedCharacterRange != nil &&
                    (ext == "swift" || ext == "m" || ext == "mm" || ext == "c" || ext == "h")
                }.sorted(by: {
                    return mtime(($0 as! SBObject).path) < mtime(($1 as! SBObject).path)
                }).last

            if let sourceDoc = relevantDoc as? SBObject {
                print("relevantDoc: \(sourceDoc.path!)")
                let sourcePath = sourceDoc.path.url.resolvingSymlinksInPath().path

//                if let onDisk = try? String(contentsOfFile: sourceDoc.path, encoding: .utf8),
//                    sourceDoc.text != onDisk {
//                    print(sourceDoc.text)
//                    try? sourceDoc.text.write(toFile: sourceDoc.path, atomically: false, encoding: .utf8)
//                }

                do {
                    let sourceString = try NSString( contentsOfFile: sourcePath, encoding: String.Encoding.utf8.rawValue )
                    let range = sourceDoc.selectedCharacterRange
                    let sourceOffset = range == nil ? nil :
                        sourceString.substring(with: NSMakeRange(0, range![0].intValue-1)).utf8.count

                    entity = Entity( file: sourcePath, offset: sourceOffset )
                }
                catch (let e) {
                    xcode.error( "Could not load source \(sourcePath) - \(e)" )
                }
            }
        }

        if target != nil && !IndexDB.projectIncludes(file: target!.file),
            let alternate = Project.findProject(for: target!) {
            workspacePath = alternate
            workspaceDoc = nil
            do {
                (projectRoot, derivedData, indexPath, indexDB) =
                    try Project.openWorkspace(workspaceDoc: workspaceDoc, workspacePath: workspacePath, relative: true)
                print("alternate workspace: \(workspacePath)")
            }
            catch {
                do {
                    (projectRoot, derivedData, indexPath, indexDB) =
                        try Project.openWorkspace(workspaceDoc: workspaceDoc, workspacePath: workspacePath, relative: false)
                    print("alternate workspace: \(workspacePath)")
                }
                catch {
                    xcode.error("Error finding indexDB for \(workspacePath)")
                }
            }
        }

        if indexDB == nil && Project.lastProject?.indexDB != nil, let previous = Project.lastProject {
            (workspacePath, projectRoot, derivedData, indexPath, indexDB) =
                (previous.workspacePath, previous.projectRoot, previous.derivedData,
                 previous.indexPath, IndexDB(dbPath: previous.indexPath))
        }

        super.init()
        Project.lastProject = self
    }

}
