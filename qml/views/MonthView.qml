pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller

    readonly property bool compact: width < WaypointTheme.calendarSplitBreakpoint
    readonly property int pageMargin: compact ? 18 : 34
    readonly property date now: new Date()
    readonly property int elapsedDays: Math.floor((now - new Date(now.getFullYear(), 0, 1)) / 86400000) + 1
    readonly property int daysInYear: new Date(now.getFullYear(), 1, 29).getMonth() === 1 ? 366 : 365
    readonly property date selectedDateValue: {
        const parts = controller.selectedDateKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function holidayColor(kind) {
        if (kind === "legal")
            return WaypointTheme.urgent;
        if (kind === "optional")
            return WaypointTheme.accent;
        return WaypointTheme.warning;
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

    ScrollView {
        id: page
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        GridLayout {
            x: root.pageMargin
            y: root.pageMargin
            width: Math.max(0, page.availableWidth - root.pageMargin * 2)
            height: root.compact ? implicitHeight : Math.max(0, page.availableHeight - root.pageMargin * 2)
            columns: root.compact ? 1 : 3
            columnSpacing: root.compact ? 0 : 30
            rowSpacing: root.compact ? 20 : 0

            Item {
                id: calendarPane
                Layout.fillWidth: true
                Layout.fillHeight: !root.compact
                Layout.preferredHeight: calendarColumn.implicitHeight
                Layout.maximumWidth: 520
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

                ColumnLayout {
                    id: calendarColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 0

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        AppIcon {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            name: "calendar"
                            color: WaypointTheme.foreground
                            strokeWidth: 2
                        }

                        Text {
                            text: Qt.locale().toString(root.selectedDateValue, "MMMM d")
                            color: WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: root.compact ? WaypointTheme.displaySize : WaypointTheme.displayLargeSize
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 18
                        Layout.bottomMargin: 22
                        spacing: 12

                        Text {
                            text: root.now.getFullYear()
                            color: WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.captionSize
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: WaypointTheme.controlFill
                            border.width: 1
                            border.color: WaypointTheme.divider

                            Rectangle {
                                width: parent.width * root.elapsedDays / root.daysInYear
                                height: parent.height
                                radius: 3
                                color: WaypointTheme.activeBorder
                            }
                        }

                        Text {
                            text: Math.round(root.elapsedDays * 100 / root.daysInYear) + "%"
                            color: WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.captionSize
                        }
                    }

                    CalendarGrid {
                        id: calendarGrid
                        Layout.alignment: Qt.AlignHCenter
                        calendarModel: root.controller.calendar
                        selectedDateKey: root.controller.selectedDateKey
                        onDaySelected: selectedDateKey => root.controller.selectedDateKey = selectedDateKey
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 16

                        AppButton {
                            text: "‹"
                            square: true
                            onClicked: root.controller.calendar.showPreviousMonth()
                            ToolTip.visible: hovered
                            ToolTip.text: "Mês anterior"
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        AppButton {
                            text: root.controller.calendar.monthLabel.toUpperCase()
                            onClicked: root.controller.calendar.showCurrentMonth()
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        AppButton {
                            text: "›"
                            square: true
                            onClicked: root.controller.calendar.showNextMonth()
                            ToolTip.visible: hovered
                            ToolTip.text: "Próximo mês"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: root.compact
                Layout.fillHeight: !root.compact
                Layout.preferredWidth: root.compact ? 0 : 1
                Layout.preferredHeight: root.compact ? 1 : 0
                color: WaypointTheme.divider
            }

            Item {
                id: taskPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.compact ? 360 : 0
                Layout.preferredHeight: root.compact ? 360 : 0
                Layout.alignment: Qt.AlignTop

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: Qt.locale().toString(root.selectedDateValue, "dddd, d MMMM")
                            color: WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.headingSize
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        TaskVisibilityChip {
                            controller: root.controller
                        }
                    }

                    Text {
                        Layout.topMargin: 6
                        text: {
                            const pending = root.controller.selectedDateTasks.pendingCount;
                            const skipped = root.controller.selectedDateTasks.skippedCount;
                            const pendingLabel = pending + " pendente" + (pending === 1 ? "" : "s");
                            return skipped === 0 ? pendingLabel
                                 : pendingLabel + " · " + skipped + " não feita" + (skipped === 1 ? "" : "s");
                        }
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.captionSize
                        font.letterSpacing: 1
                    }

                    Repeater {
                        model: root.controller.selectedDateHolidays

                        Rectangle {
                            id: holidayCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            Layout.preferredHeight: holidayContent.implicitHeight + 18
                            radius: WaypointTheme.radius
                            color: WaypointTheme.controlFill
                            border.width: 1
                            border.color: root.holidayColor(modelData.kind)

                            ColumnLayout {
                                id: holidayContent
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: holidayCard.modelData.name
                                    color: root.holidayColor(holidayCard.modelData.kind)
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.subtitleSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: root.holidayKindLabel(holidayCard.modelData.kind,
                                                                holidayCard.modelData.scope)
                                    color: root.holidayColor(holidayCard.modelData.kind)
                                    opacity: 0.72
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.captionSize
                                    font.bold: true
                                    font.letterSpacing: 0.8
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: holidayCard.modelData.description !== ""
                                    text: holidayCard.modelData.description
                                    color: WaypointTheme.subduedText
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.bodySmallSize
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }

                    QuickTaskComposer {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        controller: root.controller
                        scheduledDateKey: root.controller.selectedDateKey
                        placeholderText: "Nova tarefa neste dia…"
                    }

                    ListView {
                        id: selectedTasks
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 12
                        clip: true
                        spacing: 2
                        model: root.controller.selectedDateTasks

                        delegate: TaskRow {
                            width: selectedTasks.width
                            controller: root.controller
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: selectedTasks.count === 0
                            text: root.controller.taskVisibility === "pending"
                                ? "Nenhuma tarefa pendente neste dia."
                                : "Clique acima para planejar este dia."
                            color: WaypointTheme.disabledText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySize
                        }
                    }
                }
            }
        }
    }
}
