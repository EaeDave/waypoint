pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 42
        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 5

                Text {
                    text: "Hoje"
                    color: "#f6f4f8"
                    font.pixelSize: 38
                    font.bold: true
                }

                Text {
                    text: Qt.locale().toString(new Date(), "dddd, d MMMM")
                    color: "#817e87"
                    font.family: "monospace"
                    font.pixelSize: 12
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: connectionLabel.implicitWidth + 20
                Layout.preferredHeight: 28
                radius: 14
                color: root.controller.online ? "#111813" : "#211116"

                Text {
                    id: connectionLabel
                    anchors.centerIn: parent
                    text: root.controller.online ? "LOCAL" : "OFFLINE"
                    color: root.controller.online ? "#81d39a" : "#ff7085"
                    font.family: "monospace"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 34
            Layout.bottomMargin: 15

            Text {
                text: root.controller.todayTasks.overdueCount > 0 ? root.controller.todayTasks.overdueCount + " atrasada" + (root.controller.todayTasks.overdueCount === 1 ? "" : "s") : root.controller.todayTasks.pendingCount + " pendente" + (root.controller.todayTasks.pendingCount === 1 ? "" : "s")
                color: root.controller.todayTasks.overdueCount > 0 ? "#ff7085" : "#aaa7ad"
                font.family: "monospace"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "N  NOVA TAREFA"
                color: "#5f5c65"
                font.family: "monospace"
                font.pixelSize: 9
                font.letterSpacing: 1
            }
        }

        QuickTaskComposer {
            id: composer
            Layout.fillWidth: true
            controller: root.controller
            scheduledDateKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 14
            clip: true

            ListView {
                id: taskList
                model: root.controller.todayTasks
                spacing: 2

                delegate: TaskRow {
                    width: taskList.width
                    controller: root.controller
                }

                Text {
                    anchors.centerIn: parent
                    visible: taskList.count === 0
                    text: "Seu dia está livre."
                    color: "#5f5c65"
                    font.pixelSize: 15
                }
            }
        }
    }

    Shortcut {
        sequence: "N"
        onActivated: composer.focusInput()
    }
}
