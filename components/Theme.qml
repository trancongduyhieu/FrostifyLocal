pragma Singleton
import QtQuick

QtObject {
    // Spotify Dark Modern Theme Colors (100% true to official Spotify Desktop)
    readonly property color bgApp: "#121212"          // Spotify deepest black/gray window background
    readonly property color bgCard: "#181818"         // Spotify card background
    readonly property color bgCardHover: "#282828"    // Spotify card hover state
    readonly property color bgElevated: "#242424"     // Floating cards / menus
    readonly property color bgHighlight: "#2a2a2a"    // Active row highlight
    
    // Borders & Dividers
    readonly property color border: "#282828"         // Subtle hairline border
    readonly property color divider: "#1f1f1f"        // Hairline divider

    // Typography Colors (Apple/Spotify standard)
    readonly property color textPrimary: "#ffffff"    // 100% white bold text
    readonly property color textSecondary: "#b3b3b3"  // Muted 70% gray subtitle
    readonly property color textMuted: "#727272"      // Dim 45% gray icons/counters

    // Brand Accents
    readonly property color spotifyGreen: "#1db954"   // Official Spotify vibrant green
    readonly property color spotifyGreenHover: "#1ed760"
    readonly property color accentPill: "#ffffff"
    readonly property color accentPillText: "#000000"

    // Typography Family (Using system premium SF Pro / Inter)
    readonly property string fontFamily: "Inter, SF Pro Display, -apple-system, sans-serif"

    // Spacing and Radii (Exact Spotify ratios)
    readonly property int radiusApp: 12
    readonly property int radiusCard: 8
    readonly property int radiusPill: 16
    readonly property int radiusSm: 4
}
