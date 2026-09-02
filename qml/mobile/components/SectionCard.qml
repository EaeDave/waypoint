import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    default property alias content: body.data
    property int contentSpacing: 10

    implicitHeight: body.implicitHeight + 24
    radius: MobileTheme.radius
    color: MobileTheme.surface
    border.width: 1
    border.color: MobileTheme.divider

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 12
        spacing: root.contentSpacing
    }
}
