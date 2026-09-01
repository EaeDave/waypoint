import QtQuick
import QtQuick.Controls

TextField {
    id: control

    implicitHeight: WaypointTheme.controlHeight
    leftPadding: 10
    rightPadding: 10
    topPadding: 6
    bottomPadding: 6
    selectByMouse: true
    color: WaypointTheme.foreground
    placeholderTextColor: WaypointTheme.disabledText
    selectionColor: WaypointTheme.accent
    selectedTextColor: WaypointTheme.background
    font.family: WaypointTheme.fontFamily
    font.pixelSize: WaypointTheme.bodySize

    background: Rectangle {
        radius: WaypointTheme.radius
        color: control.activeFocus || control.hovered ? WaypointTheme.controlHoverFill : WaypointTheme.controlFill
        border.width: 1
        border.color: control.activeFocus ? WaypointTheme.activeBorder
                    : control.hovered ? WaypointTheme.controlHoverBorder
                    : WaypointTheme.controlBorder
    }
}
