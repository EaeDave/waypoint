import QtQuick
import QtQuick.Controls

Button {
    id: control

    property bool selected: false
    property bool destructive: false
    property bool square: false

    implicitWidth: square ? implicitHeight : Math.max(72, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: WaypointTheme.controlHeight
    leftPadding: square ? 0 : 10
    rightPadding: square ? 0 : 10
    topPadding: 6
    bottomPadding: 6
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        color: !control.enabled ? WaypointTheme.disabledText
             : control.destructive ? WaypointTheme.urgent
             : WaypointTheme.foreground
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.bodySmallSize
        font.bold: control.selected
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: WaypointTheme.radius
        color: control.down || control.selected ? WaypointTheme.controlSelectedFill
             : control.hovered ? WaypointTheme.controlHoverFill
             : WaypointTheme.controlFill
        border.width: 1
        border.color: !control.enabled ? WaypointTheme.divider
                    : control.destructive ? WaypointTheme.urgent
                    : control.activeFocus || control.selected ? WaypointTheme.activeBorder
                    : control.hovered ? WaypointTheme.controlHoverBorder
                    : WaypointTheme.controlBorder
    }
}
