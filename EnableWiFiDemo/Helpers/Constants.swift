//
//  Constants.swift
//  EnableWiFiDemo
//
//  Created by Marchell on 11/27/24.
//

import Foundation

let goProDefaultIPAddress: String = "10.5.5.9"

var startStreamURL: (String) -> String = { ip in
    return "http://\(ip)/gp/gpControl/command/transcode/start?res=720p"
}

var startStreamUsingPortURL: (String) -> String = { ip in
    return "http://\(ip):8080/gopro/camera/stream/start"
}

var stopStreamURL: (String) -> String = { ip in
    return "http://\(ip):8080/gopro/camera/stream/stop"
}

var liveFeedURL: (String) -> String = { ip in
    return "rtsp://\(ip):8556/live"
}

var mediaListURL: (String) -> String = { ip in
    return "http://\(ip):8080/gopro/media/list"
}

var mediaDownloadURL: (String, String, String) -> String = { ip, directory, fileName in
    return "http://\(ip):8080/videos/DCIM/\(directory)/\(fileName)"
}
