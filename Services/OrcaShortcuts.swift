//
//  OrcaShortcuts.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import AppIntents

struct DropMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Drop a Memory"
    static var description = IntentDescription("Quickly capture a voice memory in Orca")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openDropOverlay, object: nil)
        return .result()
    }
}

struct TypeMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Type a Memory"
    static var description = IntentDescription("Type a new memory in Orca")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openTypeCapture, object: nil)
        return .result()
    }
}

struct ScreenshotMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Screenshot Memory"
    static var description = IntentDescription("Capture a screenshot as a memory in Orca")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openScreenshotCapture, object: nil)
        return .result()
    }
}

struct OrcaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DropMemoryIntent(),
            phrases: [
                "Drop a memory in \(.applicationName)",
                "Record a memory in \(.applicationName)",
                "Capture in \(.applicationName)",
                "\(.applicationName) drop"
            ],
            shortTitle: "Drop Memory",
            systemImageName: "waveform"
        )
        
        AppShortcut(
            intent: TypeMemoryIntent(),
            phrases: [
                "Type a memory in \(.applicationName)",
                "Write a memory in \(.applicationName)",
                "Note in \(.applicationName)"
            ],
            shortTitle: "Type Memory",
            systemImageName: "keyboard"
        )
        
        AppShortcut(
            intent: ScreenshotMemoryIntent(),
            phrases: [
                "Screenshot in \(.applicationName)",
                "Scan in \(.applicationName)"
            ],
            shortTitle: "Screenshot Memory",
            systemImageName: "camera.viewfinder"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    @MainActor static let openDropOverlay = Notification.Name("openDropOverlay")
    @MainActor static let resetToToday = Notification.Name("resetToToday")
    @MainActor static let openTypeCapture = Notification.Name("openTypeCapture")
    @MainActor static let openScreenshotCapture = Notification.Name("openScreenshotCapture")
}
