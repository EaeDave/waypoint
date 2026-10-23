pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var calendarModel
    required property string selectedDateKey
    signal daySelected(string selectedDateKey)

    implicitWidth: 7 * 58 + 6 * 5 + 34
    // Week column (23) + gaps and divider (11) + six cell gaps (30).
    readonly property real cellWidth: Math.max(36, Math.floor((width - 64) / 7))
    implicitHeight: weekdayHeader.height + 6 * 48 + 6 * 5

    readonly property var weekdayLabels: ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]

    RowLayout {
        id: weekdayHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 5

        Text {
            Layout.preferredWidth: 29
            rightPadding: 6
            text: "S"
            color: WaypointTheme.disabledText
            horizontalAlignment: Text.AlignHCenter
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.captionSize
            font.weight: WaypointTheme.weightMedium
            Accessible.name: "Semana"
        }

        Repeater {
            model: root.weekdayLabels

            Text {
                required property string modelData
                Layout.preferredWidth: root.cellWidth
                text: modelData
                color: WaypointTheme.disabledText
                horizontalAlignment: Text.AlignHCenter
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.weight: WaypointTheme.weightMedium
            }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: weekdayHeader.bottom
        anchors.topMargin: 5
        spacing: 5

        Column {
            width: 23
            spacing: 5

            Repeater {
                model: 6

                Text {
                    required property int index
                    width: 23
                    height: 48
                    text: root.calendarModel.weekNumberAtRow(index)
                    color: WaypointTheme.disabledText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.captionSize
                    font.features: WaypointTheme.tabularNumbers
                }
            }
        }

        Rectangle {
            width: 1
            height: 6 * 48 + 5 * 5
            color: WaypointTheme.divider
        }

        Grid {
            columns: 7
            columnSpacing: 5
            rowSpacing: 5

            Repeater {
                model: root.calendarModel

                CalendarDay {
                    width: root.cellWidth
                    selected: calendarDateKey === root.selectedDateKey
                    onActivated: selectedDateKey => root.daySelected(selectedDateKey)
                }
            }
        }
    }
}
