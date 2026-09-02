import QtQuick
import QtQuick.Controls

TextField {
    id: root

    implicitHeight: MobileTheme.touchHeight
    color: MobileTheme.foreground
    placeholderTextColor: MobileTheme.disabled
    selectionColor: MobileTheme.accent
    selectedTextColor: MobileTheme.background
    font.family: MobileTheme.fontFamily
    font.pixelSize: MobileTheme.bodySize
    leftPadding: 14
    rightPadding: 14

    background: Rectangle {
        radius: MobileTheme.radius
        color: MobileTheme.surfaceRaised
        border.width: 1
        border.color: root.activeFocus ? MobileTheme.activeBorder : MobileTheme.border
    }
}
