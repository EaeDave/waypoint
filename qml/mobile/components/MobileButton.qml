import QtQuick
import QtQuick.Controls

Button {
    id: root

    property bool accent: false
    property bool destructive: false
    property bool quiet: false

    implicitHeight: MobileTheme.touchHeight
    leftPadding: 14
    rightPadding: 14

    contentItem: Text {
        text: root.text
        color: !root.enabled ? MobileTheme.disabled : root.destructive ? MobileTheme.urgent : root.accent ? MobileTheme.background : MobileTheme.foreground
        font.family: MobileTheme.fontFamily
        font.pixelSize: MobileTheme.bodySize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: MobileTheme.radius
        color: !root.enabled ? MobileTheme.surface : root.down ? MobileTheme.surfacePressed : root.accent ? MobileTheme.accent : root.quiet ? "transparent" : MobileTheme.surfaceRaised
        border.width: root.quiet || root.accent ? 0 : 1
        border.color: root.destructive ? MobileTheme.urgent : MobileTheme.border
    }
}
