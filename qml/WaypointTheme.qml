pragma Singleton

import QtQuick

QtObject {
    readonly property color background: "#070506"
    readonly property color foreground: "#ffffff"
    readonly property color accent: "#979fec"
    readonly property color activeBorder: "#e4e6fb"
    readonly property color muted: "#836f79"
    readonly property color urgent: "#b37580"
    readonly property color success: "#9ec49f"
    readonly property color warning: "#e9c98d"

    readonly property color surface: Qt.rgba(1, 1, 1, 0.025)
    readonly property color controlFill: Qt.rgba(1, 1, 1, 0.04)
    readonly property color controlHoverFill: Qt.rgba(1, 1, 1, 0.08)
    readonly property color controlSelectedFill: Qt.rgba(1, 1, 1, 0.18)
    readonly property color controlBorder: Qt.rgba(1, 1, 1, 0.40)
    readonly property color controlHoverBorder: Qt.rgba(1, 1, 1, 0.25)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.12)
    readonly property color subduedText: Qt.rgba(1, 1, 1, 0.58)
    readonly property color disabledText: Qt.rgba(1, 1, 1, 0.34)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.50)

    readonly property int radius: 4
    readonly property int controlHeight: 32
    readonly property int panelPadding: 18
    readonly property int popupPadding: 14
    readonly property int controlGap: 8
    readonly property int compactBreakpoint: 680
    readonly property int calendarSplitBreakpoint: 900

    readonly property string fontFamily: "monospace"
    readonly property int captionSize: 10
    readonly property int bodySmallSize: 11
    readonly property int bodySize: 12
    readonly property int subtitleSize: 13
    readonly property int titleSize: 14
    readonly property int headingSize: 16
    readonly property int displaySize: 24
    readonly property int displayLargeSize: 28
}
