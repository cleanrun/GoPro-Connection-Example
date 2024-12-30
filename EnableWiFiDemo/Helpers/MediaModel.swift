//
//  MediaModel.swift
//  EnableWiFiDemo
//
//  Created by Marchell on 11/27/24.
//

import Foundation

struct MediaList: Codable {
    let id: String
    let medias: [MediaDirectory]
    
    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case medias = "media"
    }
}

struct MediaDirectory: Codable {
    let directory: String
    let files: [MediaFile]
    
    private enum CodingKeys: String, CodingKey {
        case directory = "d"
        case files = "fs"
    }
}

struct MediaFile: Codable, Identifiable {
    var id = UUID()
    
    let name: String
    let created: String
    let mod: String
    let size: String
    let directory: String?
    
    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "n"
        case created = "cre"
        case mod = "mod"
        case size = "s"
        case directory = "d"
    }
    
    init(mediaFile: MediaFile, directory: String) {
        self.name = mediaFile.name
        self.created = mediaFile.created
        self.mod = mediaFile.mod
        self.size = mediaFile.size
        self.directory = directory
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.created = try container.decode(String.self, forKey: .created)
        self.mod = try container.decode(String.self, forKey: .mod)
        self.size = try container.decode(String.self, forKey: .size)
        self.directory = nil
    }
}
