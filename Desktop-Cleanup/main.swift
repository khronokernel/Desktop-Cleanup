//
//  main.swift
//  Desktop-Cleanup
//
//  Created by Mykola Grymalyuk on 2023-07-07.
//


/*
    Goal of this application is simple:
    - Every time it is run, check for old screenshots
    - If there are more than 14 screenshots on the desktop, move them to a folder called "Old Screenshots"
*/

import Foundation

let APPLICATION_VERSION = "1.0.0"
var images_to_keep = 14

print("Desktop Cleanup v\(APPLICATION_VERSION)")

let homePath = FileManager.default.homeDirectoryForCurrentUser
let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
let desktopFiles = try! FileManager.default.contentsOfDirectory(atPath: desktopPath.path)

let screenshots = desktopFiles.filter { $0.contains("Screenshot") }

if screenshots.count > 14 {
    print("Found \(screenshots.count) screenshots on the desktop. Moving oldest screenshots to \"Old Screenshots\" folder.")

    let oldScreenshotsFolder = homePath.appendingPathComponent("Old Screenshots")

    if !FileManager.default.fileExists(atPath: oldScreenshotsFolder.path) {
        try! FileManager.default.createDirectory(at: oldScreenshotsFolder, withIntermediateDirectories: false, attributes: nil)
    }

    // Grab age of each screenshot
    var screenshotAges = [String: Date]()
    for screenshot in screenshots {
        let screenshotPath = desktopPath.appendingPathComponent(screenshot)
        let attributes = try! FileManager.default.attributesOfItem(atPath: screenshotPath.path)
        let creationDate = attributes[FileAttributeKey.creationDate] as! Date
        screenshotAges[screenshot] = creationDate
    }

    // Sort screenshots by age
    let sortedScreenshotAges = screenshotAges.sorted { $0.value < $1.value }
    let screenshotsToKeep = sortedScreenshotAges.suffix(images_to_keep)

    // Move old screenshots to "Old Screenshots" folder
    var index = 0
    for screenshot in sortedScreenshotAges {
        if !screenshotsToKeep.contains(where: { $0.key == screenshot.key }) {
            index += 1
            print("\(index). \(screenshot.key) - \(screenshot.value)")
            let screenshotPath = desktopPath.appendingPathComponent(screenshot.key)
            let newScreenshotPath = oldScreenshotsFolder.appendingPathComponent(screenshot.key)
            try! FileManager.default.moveItem(at: screenshotPath, to: newScreenshotPath)
        }
    }

} else {
    print("Found \(screenshots.count) screenshots on the desktop. Nothing to do.")
}