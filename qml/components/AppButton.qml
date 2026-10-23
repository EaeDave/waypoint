import QtQuick
import QtQuick.Controls

// Variants: default (soft outline), `highlighted` (primary action), `flat` (ghost),
// `selected` (toggle on), `destructive`.
Button {
    id: control

    property bool selected: false
    property bool destructive: false
    property bool square: false

    implicitWidth: square ? implicitHeight : Math.max(64, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: WaypointTheme.controlHeight
    leftPadding: square ? 0 : 12
    rightPadding: square ? 0 : 12
    topPadding: 6
    bottomPadding: 6
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        color: !control.enabled ? WaypointTheme.disabledText
             : control.highlighted ? WaypointTheme.background
             : control.destructive ? WaypointTheme.urgent
             : control.selected ? WaypointTheme.accent
             : WaypointTheme.foreground
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.bodySmallSize
        font.weight: control.highlighted || control.selected ? WaypointTheme.weightSemiBold
                                                             : WaypointTheme.weightMedium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: WaypointTheme.radius
        color: control.highlighted
               ? (!control.enabled ? WaypointTheme.controlFill
                  : control.down ? Qt.darker(WaypointTheme.accent, 1.15)
                  : control.hovered ? Qt.lighter(WaypointTheme.accent, 1.08)
                  : WaypointTheme.accent)
             : control.selected ? WaypointTheme.accentSoft
             : control.down ? WaypointTheme.controlSelectedFill
             : control.hovered ? WaypointTheme.controlHoverFill
             : control.flat ? "transparent"
             : WaypointTheme.controlFill
        border.width: control.activeFocus || !(control.flat || control.highlighted || control.selected) ? 1 : 0
        border.color: control.activeFocus ? WaypointTheme.activeBorder
                    : control.destructive && control.enabled ? Qt.rgba(0.788, 0.522, 0.569, 0.45)
                    : control.hovered ? WaypointTheme.controlHoverBorder
                    : WaypointTheme.controlBorder
    }
}
