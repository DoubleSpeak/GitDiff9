//
//  LNExtensionBase.swift
//  LNProvider
//
//  Created by John Holdsworth on 06/04/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

import Cocoa

var xcode: AppLogging!

protocol AppLogging {
    func log(_ msg: String)
    func error(_ msg: String)
}

let implementationFactory = UnusedImpl.self

class UnusedImpl: LNExtensionBase, LNExtensionService, AppLogging {

    func log(_ msg: String) {
        NSLog(msg)
    }

    func error(_ msg: String) {
        log("<div class=error>\(msg)</div>")
    }

    public func requestHighlights(forFile filepath: String, callback: @escaping LNHighlightCallback) {
        xcode = self

        let unusedColor = DefaultManager().unusedColor
        let project = Project(target: Entity(file: filepath))
        let highlights = LNFileHighlights()

        if let indexDB = project.indexDB {
            for lineNumber in indexDB.unusedDefinitions(forFile: filepath) {
                let highlight = LNHighlightElement()
                highlight.start = lineNumber
                highlight.color = unusedColor
                highlights[lineNumber] = highlight
            }

            callback(highlights.jsonData(), nil)
        } else {
            callback(nil, nil)
        }
    }

}

extension IndexDB {

    func unusedDefinitions(forFile path: String) -> [Int] {
        guard let (fileid, fileID, dirID) = lookup(filePath: path) else { return [] }
        var out = [Int]()

        let SQL =
            "select lineNumber " +
            " from symbol t " +
            " inner join group_ g on (g.id = t.group_)" +
            " inner join file f on (f.id = g.file)" +
            " where f.lowercaseFilename = ? and f.filename = ? and f.directory = ? and \(roleIsDecl)" +
            "  and not exists(select 1 from reference r where t.resolution = r.resolution)"

        guard select(sql: SQL, ids: [fileid, fileID, dirID], row: {
            stmt in
            out.append(Int(sqlite3_column_int64(stmt, 0)))
        }) else {
            xcode.error("Dependencies prepare error \(error)"); return []
        }

        return out
    }
    
}
