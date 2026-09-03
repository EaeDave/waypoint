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
    required property int skippedCount
    required property int holidayCount
    required property string holidayKind
    required property var holidayNames
    property bool selected: false

    signal activated(string selectedDateKey)

    function holidayColor(kind) {
        if (kind === "legal")
            return WaypointTheme.urgent;
        if (kind === "optional")
            return WaypointTheme.accent;
        return WaypointTheme.warning;
    }

    implicitWidth: 58
    implicitHeight: 48
    radius: WaypointTheme.radius
    color: root.selected ? WaypointTheme.controlSelectedFill
         : pointer.containsMouse ? WaypointTheme.controlHoverFill
         : "transparent"
    border.width: root.today || root.selected ? 1 : 0
    border.color: root.selected ? WaypointTheme.activeBorder : WaypointTheme.controlBorder

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -3
        text: root.dayNumber
        color: root.inVisibleMonth
             ? root.holidayCount > 0 ? root.holidayColor(root.holidayKind)
             : root.weekend ? WaypointTheme.subduedText : WaypointTheme.foreground
             : WaypointTheme.disabledText
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.subtitleSize
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

        Text {
            visible: root.skippedCount > 0
            text: root.skippedCount === 1 ? "×" : "×" + root.skippedCount
            color: WaypointTheme.urgent
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.captionSize
            font.bold: true
        }

        Repeater {
            model: Math.min(root.pendingCount, 3)

            Rectangle {
                required property int index
                width: 4
                height: 4
                radius: 2
                color: root.overdueCount > index ? WaypointTheme.urgent : WaypointTheme.accent
            }
        }

        Rectangle {
            visible: root.pendingCount === 0 && root.skippedCount === 0 && root.completedCount > 0
            width: 4
            height: 4
            radius: 2
            color: "transparent"
            border.width: 1
            border.color: WaypointTheme.subduedText
        }
    }

    ToolTip.visible: pointer.containsMouse
                         && (root.pendingCount + root.completedCount + root.skippedCount
                             + root.holidayCount) > 0
    ToolTip.text: {
        const pending = root.pendingCount > 0
            ? root.pendingCount + " pendente" + (root.pendingCount === 1 ? "" : "s") : "";
        const completed = root.completedCount > 0
            ? root.completedCount + " concluída" + (root.completedCount === 1 ? "" : "s") : "";
        const skipped = root.skippedCount > 0
            ? root.skippedCount + " não feita" + (root.skippedCount === 1 ? "" : "s") : "";
        const taskSummary = [pending, completed, skipped].filter(part => part !== "").join(" · ");
        const holidaySummary = root.holidayCount > 0 ? root.holidayNames.join(" · ") : "";
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
