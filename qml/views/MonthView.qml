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

    RowLayout {
        anchors.fill: parent
        anchors.margins: 34
        spacing: 30

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 520
            spacing: 0

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16

                AppIcon {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    name: "calendar"
                    color: "#f6f4f8"
                    strokeWidth: 2.2
                }

                Text {
                    text: Qt.locale().toString(root.selectedDateValue, "MMMM d")
                    color: "#f6f4f8"
                    font.pixelSize: 38
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.bottomMargin: 24
                spacing: 12

                Text {
                    text: root.now.getFullYear()
                    color: "#77737e"
                    font.family: "monospace"
                    font.pixelSize: 10
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    color: "#242329"

                    Rectangle {
                        width: parent.width * root.elapsedDays / root.daysInYear
                        height: parent.height
                        color: "#f2f0f5"
                    }
                }

                Text {
                    text: Math.round(root.elapsedDays * 100 / root.daysInYear) + "%"
                    color: "#b5b1ba"
                    font.family: "monospace"
                    font.pixelSize: 10
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
                Layout.topMargin: 17

                ToolButton {
                    text: "‹"
                    onClicked: root.controller.calendar.showPreviousMonth()
                    ToolTip.visible: hovered
                    ToolTip.text: "Mês anterior"
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: root.controller.calendar.monthLabel.toUpperCase()
                    flat: true
                    onClicked: root.controller.calendar.showCurrentMonth()
                }

                Item {
                    Layout.fillWidth: true
                }

                ToolButton {
                    text: "›"
                    onClicked: root.controller.calendar.showNextMonth()
                    ToolTip.visible: hovered
                    ToolTip.text: "Próximo mês"
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: "#242329"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Text {
                text: Qt.locale().toString(root.selectedDateValue, "dddd, d MMMM")
                color: "#f2f0f5"
                font.pixelSize: 21
                font.bold: true
            }

            Text {
                Layout.topMargin: 6
                text: root.controller.selectedDateTasks.pendingCount + " pendente" + (root.controller.selectedDateTasks.pendingCount === 1 ? "" : "s")
                color: "#817e87"
                font.family: "monospace"
                font.pixelSize: 10
                font.letterSpacing: 1
            }

            QuickTaskComposer {
                Layout.fillWidth: true
                Layout.topMargin: 22
                controller: root.controller
                scheduledDateKey: root.controller.selectedDateKey
                placeholderText: "Nova tarefa neste dia…"
            }

            ListView {
                id: selectedTasks
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 13
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
                    text: "Clique acima para planejar este dia."
                    color: "#5f5c65"
                    font.pixelSize: 13
                }
            }
        }
    }
}
