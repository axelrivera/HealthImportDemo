//
//  Log+Debug.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import Foundation

func dLog(_ message: String, filename: String = #filePath, function: String = #function, line: Int = #line) {
    // WARNING: Must add the following flag to Other Swift Flags in Build Settings "-D DEBUG"
#if DEBUG
    print("DEBUGGER -- [\(URL(filePath: filename).lastPathComponent):\(line)] \(function) - \(message)")
#endif
}
