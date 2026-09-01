pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property string calendarDateKey
    required property int dayNumber
    required property bool inVisibleMonth
    required property bool today
    required property bool weekend
    required property int pendingCount
    required property int completedCount
    required property int overdueCount
    required property int holidayCount
    required property string holidayKind
    required property var holidayNames
    property bool selected: false

    signal activated(string selectedDateKey)
    function holidayColor(kind) {
        if (kind === "legal")
            return "#ff7085";
        if (kind === "optional")
            return "#9aa7ff";
        return "#e9b86f";
    }


    implicitWidth: 58
    implicitHeight: 48
    radius: 5
    color: selected ? "#17171b" : (pointer.containsMouse ? "#111114" : "transparent")
    border.width: today || selected ? 1 : 0
    border.color: selected ? "#b7a6ff" : "#706b86"

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -3
        text: root.dayNumber
        color: root.inVisibleMonth ? (root.holidayCount > 0 ? root.holidayColor(root.holidayKind)
                                                             : (root.weekend ? "#aaa7ad" : "#f2f0f5"))
                                   : "#5a585f"
        font.family: "monospace"
        font.pixelSize: 13
        font.bold: root.today
    }
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        visible: root.holidayCount > 0
        width: root.holidayCount > 1 ? 12 : 7
        height: 2
        radius: 1
        color: root.holidayColor(root.holidayKind)
    }


    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        spacing: 3

        Repeater {
            model: Math.min(root.pendingCount, 3)

            Rectangle {
                required property int index
                width: 4
                height: 4
                radius: 2
                color: root.overdueCount > index ? "#ff7085" : "#a997ff"
            }
        }

        Rectangle {
            visible: root.pendingCount === 0 && root.completedCount > 0
            width: 4
            height: 4
            radius: 2
            color: "transparent"
            border.width: 1
            border.color: "#69666f"
        }
    }

    ToolTip.visible: pointer.containsMouse && (pendingCount + completedCount + holidayCount) > 0
    ToolTip.text: {
        const taskSummary = pendingCount + completedCount > 0
            ? pendingCount + " pendente" + (pendingCount === 1 ? "" : "s") + (completedCount > 0 ? " · " + completedCount + " concluída" + (completedCount === 1 ? "" : "s") : "")
            : "";
        const holidaySummary = holidayCount > 0 ? holidayNames.join(" · ") : "";
        return taskSummary !== "" && holidaySummary !== "" ? taskSummary + "\n" + holidaySummary
                                                          : taskSummary + holidaySummary;
    }
    ToolTip.delay: 350

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated(root.calendarDateKey)
    }
}
