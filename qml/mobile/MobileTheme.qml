pragma Singleton

import QtQuick

QtObject {
    readonly property color background: "#070506"
    readonly property color foreground: "#ffffff"
    readonly property color accent: "#979fec"
    readonly property color activeBorder: "#e4e6fb"
    readonly property color subdued: Qt.rgba(1, 1, 1, 0.58)
    readonly property color disabled: Qt.rgba(1, 1, 1, 0.34)
    readonly property color urgent: "#b37580"
    readonly property color success: "#9ec49f"
    readonly property color warning: "#e9c98d"

    readonly property color panel: "#111013"
    readonly property color surface: Qt.rgba(1, 1, 1, 0.025)
    readonly property color surfaceRaised: Qt.rgba(1, 1, 1, 0.04)
    readonly property color surfacePressed: Qt.rgba(1, 1, 1, 0.08)
    readonly property color surfaceSelected: Qt.rgba(1, 1, 1, 0.14)
    readonly property color border: Qt.rgba(1, 1, 1, 0.24)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.12)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.60)

    readonly property string fontFamily: "monospace"
    readonly property int radius: 4
    readonly property int touchHeight: 48
    readonly property int pageMargin: 16
    readonly property int captionSize: 10
    readonly property int bodySmallSize: 11
    readonly property int bodySize: 12
    readonly property int subtitleSize: 13
    readonly property int titleSize: 16
    readonly property int displaySize: 24
}
