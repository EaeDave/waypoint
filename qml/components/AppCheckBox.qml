import QtQuick
import QtQuick.Controls

CheckBox {
    id: control

    spacing: 10
    padding: 0
    hoverEnabled: true

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 5
        opacity: control.enabled ? 1 : 0.45
        color: control.checked ? WaypointTheme.accent
             : control.hovered ? WaypointTheme.controlHoverFill
             : "transparent"
        border.width: 1.5
        border.color: control.checked ? WaypointTheme.accent
                    : control.activeFocus ? WaypointTheme.activeBorder
                    : control.hovered ? WaypointTheme.subduedText
                    : WaypointTheme.controlHoverBorder

        AppIcon {
            anchors.centerIn: parent
            width: 12
            height: 12
            visible: control.checked
            name: "check"
            color: WaypointTheme.background
            strokeWidth: 2
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
