import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customizes the block screen shown when a shielded app or site is opened.
/// Runs in its own process; keep it lightweight.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func focusScreen(_ subtitle: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: nil,
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "Blocked by FocusLock", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Stay focused", color: .white),
            primaryButtonBackgroundColor: .systemIndigo
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        focusScreen("You chose to block this app.")
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        focusScreen("You chose to block this category.")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        focusScreen("You chose to block this website.")
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        focusScreen("You chose to block this category.")
    }
}
