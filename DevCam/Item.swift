//
//  Item.swift
//  DevCam
//
//  Created by Jonathan Hines Dumitru on 1/22/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
