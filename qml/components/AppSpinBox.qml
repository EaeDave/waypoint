import QtQuick
import QtQuick.Controls

SpinBox {
    id: control

    implicitWidth: 94
    implicitHeight: WaypointTheme.controlHeight
    editable: true
    hoverEnabled: true

    contentItem: TextInput {
        z: 2
        text: control.textFromValue(control.value, control.locale)
        color: WaypointTheme.foreground
        selectionColor: WaypointTheme.accent
        selectedTextColor: WaypointTheme.background
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.bodySize
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    up.indicator: Rectangle {
        x: control.width - width
        height: control.height / 2
        implicitWidth: 26
        color: control.up.pressed ? WaypointTheme.controlSelectedFill : "transparent"
        Text {
            anchors.centerIn: parent
            text: "+"
            color: WaypointTheme.subduedText
            font.family: WaypointTheme.fontFamily
        }
    }

    down.indicator: Rectangle {
        x: control.width - width
        y: control.height / 2
        height: control.height / 2
        implicitWidth: 26
        color: control.down.pressed ? WaypointTheme.controlSelectedFill : "transparent"
        Text {
            anchors.centerIn: parent
            text: "−"
            color: WaypointTheme.subduedText
            font.family: WaypointTheme.fontFamily
        }
    }

    background: Rectangle {
        radius: WaypointTheme.radius
        color: control.activeFocus || control.hovered ? WaypointTheme.controlHoverFill : WaypointTheme.controlFill
        border.width: 1
        border.color: control.activeFocus ? WaypointTheme.activeBorder
                    : control.hovered ? WaypointTheme.controlHoverBorder
                    : WaypointTheme.controlBorder
    }
}
