import QtQuick
import QtQuick.Controls

CheckBox {
    id: root

    implicitHeight: 40
    spacing: 10

    indicator: Rectangle {
        implicitWidth: 22
        implicitHeight: 22
        x: root.leftPadding
        y: (root.height - height) / 2
        radius: MobileTheme.radius
        color: root.checked ? MobileTheme.accent : MobileTheme.surfaceRaised
        border.width: 1
        border.color: root.checked ? MobileTheme.activeBorder : MobileTheme.border

        Text {
            anchors.centerIn: parent
            visible: root.checked
            text: "✓"
            color: MobileTheme.background
            font.bold: true
            font.pixelSize: 16
        }
    }

    contentItem: Text {
        leftPadding: root.indicator.width + root.spacing
        text: root.text
        color: root.enabled ? MobileTheme.foreground : MobileTheme.disabled
        font.family: MobileTheme.fontFamily
        font.pixelSize: MobileTheme.bodySize
        verticalAlignment: Text.AlignVCenter
    }
}
