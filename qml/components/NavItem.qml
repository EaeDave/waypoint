import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sidebar entry: an icon or a list colour dot, a label and an optional count.
AbstractButton {
    id: control

    property string iconName: ""
    property color dotColor: WaypointTheme.subduedText
    property int count: -1
    property bool selected: false
    property bool collapsed: false

    implicitHeight: 34
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    leftPadding: collapsed ? 0 : 10
    rightPadding: collapsed ? 0 : 10
    Accessible.name: text
    ToolTip.visible: collapsed && hovered
    ToolTip.text: count > 0 ? text + " · " + count : text

    contentItem: RowLayout {
        spacing: 10

        Item {
            Layout.fillWidth: control.collapsed
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18

            AppIcon {
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: control.iconName !== ""
                name: control.iconName
                color: control.selected ? WaypointTheme.accent : WaypointTheme.subduedText
            }

            Rectangle {
                anchors.centerIn: parent
                visible: control.iconName === ""
                width: 8
                height: 8
                radius: 4
                color: control.dotColor
            }
        }

        Text {
            visible: !control.collapsed
            Layout.fillWidth: true
            text: control.text
            elide: Text.ElideRight
            color: control.selected ? WaypointTheme.accent : WaypointTheme.foreground
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySize
            font.weight: control.selected ? WaypointTheme.weightMedium : Font.Normal
        }

        Text {
            visible: !control.collapsed && control.count > 0
            text: control.count
            color: control.selected ? WaypointTheme.accent : WaypointTheme.disabledText
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.captionSize
            font.features: WaypointTheme.tabularNumbers
        }
    }

    background: Rectangle {
        radius: WaypointTheme.radius
        color: control.selected ? WaypointTheme.accentSoft
             : control.down ? WaypointTheme.controlSelectedFill
             : control.hovered ? WaypointTheme.controlHoverFill
             : "transparent"
        border.width: control.visualFocus ? 1 : 0
        border.color: WaypointTheme.activeBorder
    }
}
