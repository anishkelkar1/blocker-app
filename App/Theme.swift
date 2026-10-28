import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Visual theme — a navy & silver take on the Freedom app's look: a soft silver
/// page, white rounded cards, bold rounded type, navy accents, and pill buttons.
enum Theme {
    static let navy = Color(red: 0.16, green: 0.30, blue: 0.56)        // accents, tint
    static let navyDeep = Color(red: 0.09, green: 0.15, blue: 0.29)    // headings, filled buttons
    static let silver = Color(red: 0.55, green: 0.59, blue: 0.66)      // secondary text
    static let line = Color(red: 0.84, green: 0.86, blue: 0.90)        // hairlines
    static let background = Color(red: 0.91, green: 0.92, blue: 0.945) // page
    static let card = Color.white
    static let danger = Color(red: 0.84, green: 0.40, blue: 0.24)      // stop / destructive

    #if canImport(UIKit)
    /// Style the navigation and tab bars to match the silver page with navy,
    /// rounded titles. Called once at startup.
    static func configureBars() {
        let bg = UIColor(Theme.background)
        let titleColor = UIColor(Theme.navyDeep)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.shadowColor = .clear
        var title: [NSAttributedString.Key: Any] = [.foregroundColor: titleColor]
        var large: [NSAttributedString.Key: Any] = [.foregroundColor: titleColor]
        if let d = UIFont.systemFont(ofSize: 17, weight: .bold).fontDescriptor.withDesign(.rounded) {
            title[.font] = UIFont(descriptor: d, size: 17)
        }
        if let d = UIFont.systemFont(ofSize: 34, weight: .bold).fontDescriptor.withDesign(.rounded) {
            large[.font] = UIFont(descriptor: d, size: 34)
        }
        nav.titleTextAttributes = title
        nav.largeTitleTextAttributes = large
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bg
        tab.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
    #endif
}

extension View {
    /// Pale silver page background behind a scrolling screen, with a matching
    /// navigation bar. Apply to the Form / List / ScrollView of every page.
    func focusLockScreen() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// A white rounded card, like the Freedom app's grouped panels.
    func card(_ padding: CGFloat = 18, radius: CGFloat = 22) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Apply the rounded font design app-wide (iOS 16.1+).
    @ViewBuilder func roundedFont() -> some View {
        if #available(iOS 16.1, *) { self.fontDesign(.rounded) } else { self }
    }
}

/// Filled navy pill button for primary actions.
struct FilledPill: ButtonStyle {
    var tint: Color = Theme.navy
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
    }
}

/// Outlined pill button for secondary / destructive actions.
struct OutlinePill: ButtonStyle {
    var tint: Color = Theme.navy
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Capsule().stroke(tint, lineWidth: 1.6))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
