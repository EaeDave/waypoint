import QtQuick
import QtQuick.Controls

MenuItem {
    id: control

    property bool destructive: false

    implicitHeight: WaypointTheme.controlHeight
    leftPadding: 10
    rightPadding: 10
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        color: !control.enabled ? WaypointTheme.disabledText
             : control.destructive ? WaypointTheme.urgent
             : WaypointTheme.foreground
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.bodySmallSize
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        color: control.highlighted ? WaypointTheme.controlSelectedFill : "transparent"
        radius: WaypointTheme.radius
    }
}
