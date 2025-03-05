/*
    Cleanup.swift
    ---------------
    Core cleanup functionality
 */

import Foundation


class Cleanup {

    let homePath:     URL
    let desktopPath:  URL
    let desktopFiles: [String]

    var imagesToKeep: Int
    var backupFolder: URL

    init(imagesToKeep: Int = defaultImagesToKeep, backupFolder: String = defaultBackupFolder) {
        self.homePath     = URL(string: NSHomeDirectory())!

        self.backupFolder = self.homePath.appendingPathComponent(backupFolder)
        self.imagesToKeep = imagesToKeep

        self.desktopPath  = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        self.desktopFiles = try! FileManager.default.contentsOfDirectory(atPath: desktopPath.path)
    }


    public func clean() {
        let screenshots = self.desktopFiles.filter { $0.contains("Screenshot") }

        if screenshots.count <= self.imagesToKeep {
            return
        }

        print("Found \(screenshots.count) screenshots on the desktop. Moving oldest screenshots to \(self.backupFolder.path)")

        let oldScreenshotsFolder = homePath.appendingPathComponent("Old Screenshots")
        let oldScreenshotsURL    = oldScreenshotsFolder.path

        if !FileManager.default.fileExists(atPath: oldScreenshotsURL) {
            try! FileManager.default.createDirectory(at: oldScreenshotsFolder, withIntermediateDirectories: true, attributes: nil)
        }

        // Grab age of each screenshot
        var screenshotAges = [String: Date]()
        for screenshot in screenshots {
            let screenshotPath = desktopPath.appendingPathComponent(screenshot)
            let attributes     = try! FileManager.default.attributesOfItem(atPath: screenshotPath.path)
            let creationDate   = attributes[.creationDate] as! Date
            screenshotAges[screenshot] = creationDate
        }

        // Sort by age
        let sortedScreenshots = screenshotAges.sorted { $0.value < $1.value }

        let screenshotsToRemove = sortedScreenshots.prefix(screenshots.count - self.imagesToKeep)

        for (screenshot, _) in screenshotsToRemove {
            let screenshotPath = desktopPath.appendingPathComponent(screenshot)
            let newScreenshotPath = oldScreenshotsFolder.appendingPathComponent(screenshot)

            try! FileManager.default.moveItem(at: screenshotPath, to: newScreenshotPath)
            print("Index \(screenshot) moved to \(newScreenshotPath.path)")
        }
    }
}


