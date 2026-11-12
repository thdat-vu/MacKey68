// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Sparkle

/// Sparkle auto-updater. The feed URL and EdDSA public key live in Info.plist.
@MainActor
enum Updater {
    static let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    static func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    static var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
}
