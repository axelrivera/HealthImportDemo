//
//  UTType+Additions.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import UniformTypeIdentifiers
import CoreServices
import UIKit

extension UTType {
    static var fitDocument: UTType {
        UTType(importedAs: "me.axelrivera.HealthImportDemo.fit")
    }
}

class FitFileDocument: UIDocument {
    
    var data: Data?
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let data = contents as? Data {
            self.data = data
        }
    }
    
}
