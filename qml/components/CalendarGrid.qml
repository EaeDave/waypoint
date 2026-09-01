pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var calendarModel
    required property string selectedDateKey
    signal daySelected(string selectedDateKey)

    implicitWidth: 7 * 58 + 6 * 5 + 28
    implicitHeight: weekdayHeader.height + 6 * 48 + 6 * 5

    readonly property var weekdayLabels: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    RowLayout {
        id: weekdayHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 5

        Text {
            Layout.preferredWidth: 23
            text: "W"
            color: "#5f5c65"
            horizontalAlignment: Text.AlignHCenter
            font.family: "monospace"
            font.pixelSize: 10
            font.bold: true
        }

        Repeater {
            model: root.weekdayLabels

            Text {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 58
                text: modelData
                color: "#817e87"
                horizontalAlignment: Text.AlignHCenter
                font.family: "monospace"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
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
                    color: "#5f5c65"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "monospace"
                    font.pixelSize: 10
                }
            }
        }

        Rectangle {
            width: 1
            height: 6 * 48 + 5 * 5
            color: "#242329"
        }

        Grid {
            columns: 7
            columnSpacing: 5
            rowSpacing: 5

            Repeater {
                model: root.calendarModel

                CalendarDay {
                    selected: calendarDateKey === root.selectedDateKey
                    onActivated: selectedDateKey => root.daySelected(selectedDateKey)
                }
            }
        }
    }
}
