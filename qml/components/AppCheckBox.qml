import QtQuick
import QtQuick.Controls

CheckBox {
    id: control

    spacing: 8
    padding: 0
    hoverEnabled: true

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: WaypointTheme.radius
        color: control.checked ? WaypointTheme.accent
             : control.hovered ? WaypointTheme.controlHoverFill
             : WaypointTheme.controlFill
        border.width: 1
        border.color: control.checked ? WaypointTheme.accent
                    : control.activeFocus ? WaypointTheme.activeBorder
                    : WaypointTheme.controlBorder

        Text {
            anchors.centerIn: parent
            visible: control.checked
            text: "✓"
            color: WaypointTheme.background
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySmallSize
            font.bold: true
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: control.enabled ? WaypointTheme.foreground : WaypointTheme.disabledText
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.bodySmallSize
        verticalAlignment: Text.AlignVCenter
    }
}
