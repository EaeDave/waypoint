pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    readonly property date now: new Date()
    readonly property int elapsedDays: Math.floor((now - new Date(now.getFullYear(), 0, 1)) / 86400000) + 1
    readonly property int daysInYear: new Date(now.getFullYear(), 1, 29).getMonth() === 1 ? 366 : 365
    readonly property date selectedDateValue: {
        const parts = controller.selectedDateKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function firstGridDate() {
        const first = new Date(controller.visibleYear, controller.visibleMonth - 1, 1);
        const mondayOffset = (first.getDay() + 6) % 7;
        first.setDate(first.getDate() - mondayOffset);
        return first;
    }

    function dateAt(index) {
        const date = firstGridDate();
        date.setDate(date.getDate() + index);
        return date;
    }

    function dateKey(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function occurrenceCount(key) {
        let count = 0;
        for (const occurrence of controller.monthOccurrences) {
            if (occurrence.occurrenceDate === key && occurrence.calendarMarker)
                ++count;
        }
        return count;
    }

    function holidayCount(key) {
        let count = 0;
        for (const holiday of controller.monthHolidays) {
            if (holiday.date === key)
                ++count;
        }
        return count;
    }

    function holidayPriority(kind) {
        if (kind === "legal")
            return 3;
        if (kind === "optional")
            return 2;
        if (kind === "commemorative")
            return 1;
        return 0;
    }

    function holidayColor(kind) {
        if (kind === "legal")
            return MobileTheme.urgent;
        if (kind === "optional")
            return MobileTheme.accent;
        return MobileTheme.warning;
    }

    function holidayColorForDate(key) {
        let selectedKind = "";
        for (const holiday of controller.monthHolidays) {
            if (holiday.date === key && holidayPriority(holiday.kind) > holidayPriority(selectedKind))
                selectedKind = holiday.kind;
        }
        return holidayColor(selectedKind);
    }

    function holidayKindLabel(kind, scope) {
        let category = "DATA COMEMORATIVA";
        if (kind === "legal")
            category = "FERIADO";
        else if (kind === "optional")
            category = "PONTO FACULTATIVO";

        let coverage = "";
        if (scope === "national")
            coverage = "NACIONAL";
        else if (scope === "state")
            coverage = "ESTADUAL";
        else if (scope === "municipal")
            coverage = "MUNICIPAL";
        return coverage === "" ? category : category + " " + coverage;
    }

    TaskEditor {
        id: taskEditor
        controller: root.controller
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: MobileTheme.pageMargin
        anchors.rightMargin: MobileTheme.pageMargin
        spacing: 10

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.topMargin: 18

            MobileButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 48
                text: "‹"
                quiet: true
                Accessible.id: "calendar-previous-month"
                onClicked: root.controller.moveMonth(-1)
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.locale().monthName(root.controller.visibleMonth - 1, Locale.LongFormat)
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.titleSize
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.controller.visibleYear
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                }
            }

            MobileButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 48
                text: "›"
                quiet: true
                Accessible.id: "calendar-next-month"
                onClicked: root.controller.moveMonth(1)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.now.getFullYear()
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 2
                color: MobileTheme.surfaceRaised

                Rectangle {
                    width: parent.width * root.elapsedDays / root.daysInYear
                    height: parent.height
                    radius: parent.radius
                    color: MobileTheme.activeBorder
                }
            }

            Text {
                text: Math.round(root.elapsedDays * 100 / root.daysInYear) + "%"
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MobileButton {
                text: "HOJE"
                Layout.preferredHeight: 42
                Accessible.id: "calendar-today"
                onClicked: root.controller.selectToday()
            }

            Item {
                Layout.fillWidth: true
            }

            MobileButton {
                text: "+ TAREFA"
                Layout.preferredHeight: 42
                Accessible.id: "calendar-create-task"
                onClicked: taskEditor.openForCreate(root.controller.selectedDateKey)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: ["S", "T", "Q", "Q", "S", "S", "D"]

                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    text: modelData
                    color: MobileTheme.disabled
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Repeater {
                model: 42

                delegate: Rectangle {
                    id: dayCell
                    required property int index
                    readonly property date calendarDate: root.dateAt(dayCell.index)
                    readonly property string key: root.dateKey(dayCell.calendarDate)
                    readonly property bool inMonth: dayCell.calendarDate.getMonth() + 1 === root.controller.visibleMonth
                    readonly property int tasks: root.occurrenceCount(dayCell.key)
                    readonly property int holidays: root.holidayCount(dayCell.key)
                    readonly property bool selected: dayCell.key === root.controller.selectedDateKey
                    readonly property bool today: dayCell.key === root.controller.todayKey
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: MobileTheme.radius
                    color: dayCell.selected ? MobileTheme.surfaceSelected : "transparent"
                    border.width: dayCell.selected || dayCell.today ? 1 : 0
                    border.color: dayCell.selected ? MobileTheme.activeBorder : MobileTheme.divider

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        text: dayCell.calendarDate.getDate()
                        color: !dayCell.inMonth ? MobileTheme.disabled : dayCell.selected ? MobileTheme.foreground : MobileTheme.subdued
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.bodySize
                        font.bold: dayCell.today || dayCell.selected
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        spacing: 3

                        Rectangle {
                            visible: dayCell.tasks > 0
                            width: 5
                            height: 5
                            radius: 2
                            color: MobileTheme.accent
                        }

                        Rectangle {
                            visible: dayCell.holidays > 0
                            width: 5
                            height: 5
                            radius: 2
                            color: root.holidayColorForDate(dayCell.key)
                        }
                    }

                    TapHandler {
                        onTapped: root.controller.selectedDateKey = dayCell.key
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6

            Text {
                Layout.fillWidth: true
                text: Qt.locale().toString(root.selectedDateValue, "dddd, d MMMM")
                color: MobileTheme.foreground
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.subtitleSize
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: root.controller.selectedTasks.length + " tarefa" + (root.controller.selectedTasks.length === 1 ? "" : "s")
                color: MobileTheme.subdued
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.captionSize
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.controller.selectedDateHolidays

                    delegate: Rectangle {
                        id: holidayRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: holidayText.implicitHeight + 18
                        radius: MobileTheme.radius
                        color: MobileTheme.surface
                        border.width: 1
                        border.color: root.holidayColor(holidayRow.modelData.kind)

                        Text {
                            id: holidayText
                            anchors.fill: parent
                            anchors.margins: 9
                            text: root.holidayKindLabel(holidayRow.modelData.kind, holidayRow.modelData.scope) + "  ·  " + (holidayRow.modelData.name || holidayRow.modelData.title)
                            color: root.holidayColor(holidayRow.modelData.kind)
                            font.family: MobileTheme.fontFamily
                            font.pixelSize: MobileTheme.captionSize
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Repeater {
                    model: root.controller.selectedTasks

                    delegate: Rectangle {
                        id: taskRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Math.max(56, selectedTaskContent.implicitHeight + 14)
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: MobileTheme.divider
                        }

                        RowLayout {
                            id: selectedTaskContent
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 2
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                            spacing: 9

                            Button {
                                id: completionButton
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                text: taskRow.modelData.completed ? "✓" : ""
                                onClicked: root.controller.setTaskCompleted(taskRow.modelData.taskId, taskRow.modelData.occurrenceDate, taskRow.modelData.recurring, !taskRow.modelData.completed)
                                background: Rectangle {
                                    radius: MobileTheme.radius
                                    color: taskRow.modelData.completed ? MobileTheme.success : "transparent"
                                    border.width: 1
                                    border.color: taskRow.modelData.completed ? MobileTheme.success : MobileTheme.border
                                }
                                contentItem: Text {
                                    text: completionButton.text
                                    color: MobileTheme.background
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Text {
                                text: taskRow.modelData.emoji || "·"
                                color: MobileTheme.foreground
                                font.pixelSize: 18
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: taskRow.modelData.title
                                    color: taskRow.modelData.completed ? MobileTheme.disabled : MobileTheme.foreground
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.bodySize
                                    font.strikeout: taskRow.modelData.completed
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    text: taskRow.modelData.scheduledTime + (taskRow.modelData.recurrenceLabel ? "  ·  " + taskRow.modelData.recurrenceLabel : "")
                                    color: MobileTheme.subdued
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.captionSize
                                }
                            }

                            MobileButton {
                                Layout.preferredWidth: 44
                                text: "···"
                                quiet: true
                                onClicked: taskEditor.openForEdit(taskRow.modelData)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.controller.selectedTasks.length === 0 && root.controller.selectedDateHolidays.length === 0
                    text: "Nada marcado para este dia."
                    color: MobileTheme.disabled
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 14
                }

                Item {
                    Layout.preferredHeight: 16
                }
            }
        }
    }
}
