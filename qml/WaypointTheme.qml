pragma Singleton

import QtQuick

QtObject {
    readonly property color background: "#070506"
    readonly property color sidebar: "#0c0a0c"
    readonly property color popupFill: "#131013"
    readonly property color foreground: "#f3f1f4"
    readonly property color accent: "#979fec"
    readonly property color accentSoft: Qt.rgba(0.592, 0.624, 0.925, 0.16)
    readonly property color activeBorder: Qt.rgba(0.592, 0.624, 0.925, 0.75)
    readonly property color urgent: "#c98591"
    readonly property color success: "#9ec49f"
    readonly property color warning: "#e9c98d"

    readonly property color surface: Qt.rgba(1, 1, 1, 0.03)
    readonly property color controlFill: Qt.rgba(1, 1, 1, 0.05)
    readonly property color controlHoverFill: Qt.rgba(1, 1, 1, 0.08)
    readonly property color controlSelectedFill: Qt.rgba(1, 1, 1, 0.12)
    readonly property color controlBorder: Qt.rgba(1, 1, 1, 0.10)
    readonly property color controlHoverBorder: Qt.rgba(1, 1, 1, 0.18)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.07)
    readonly property color subduedText: Qt.rgba(1, 1, 1, 0.60)
    readonly property color disabledText: Qt.rgba(1, 1, 1, 0.38)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)

    readonly property int radiusSmall: 6
    readonly property int radius: 8
    readonly property int radiusLarge: 12
    readonly property int controlHeight: 34
    readonly property int panelPadding: 20
    readonly property int popupPadding: 16
    readonly property int controlGap: 8
    readonly property int compactBreakpoint: 680
    readonly property int calendarSplitBreakpoint: 900

    // Every weight registers under the same family; Text picks one through font.weight.
    readonly property FontLoader interRegular: FontLoader { source: "fonts/Inter-Regular.ttf" }
    readonly property FontLoader interMedium: FontLoader { source: "fonts/Inter-Medium.ttf" }
    readonly property FontLoader interSemiBold: FontLoader { source: "fonts/Inter-SemiBold.ttf" }
    readonly property string fontFamily: interRegular.status === FontLoader.Ready
                                         ? interRegular.font.family : "sans-serif"
    readonly property int weightMedium: Font.Medium
    readonly property int weightSemiBold: Font.DemiBold
    readonly property var tabularNumbers: ({ "tnum": 1 })

    readonly property int captionSize: 12
    readonly property int bodySmallSize: 13
    readonly property int bodySize: 14
    readonly property int subtitleSize: 15
    readonly property int titleSize: 16
    readonly property int headingSize: 18
    readonly property int displaySize: 22
    readonly property int displayLargeSize: 26
}
