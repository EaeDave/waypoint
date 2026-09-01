pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    readonly property bool compact: width < WaypointTheme.compactBreakpoint

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 18 : 34
        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 4

                Text {
                    text: "Hoje"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: root.compact ? WaypointTheme.displaySize : WaypointTheme.displayLargeSize
                    font.bold: true
                }

                Text {
                    text: Qt.locale().toString(new Date(), "dddd, d MMMM")
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: connectionLabel.implicitWidth + 20
                Layout.preferredHeight: 28
                radius: WaypointTheme.radius
                color: WaypointTheme.controlFill
                border.width: 1
                border.color: root.controller.online ? WaypointTheme.success : WaypointTheme.urgent

                Text {
                    id: connectionLabel
                    anchors.centerIn: parent
                    text: root.controller.online ? "LOCAL" : "OFFLINE"
                    color: root.controller.online ? WaypointTheme.success : WaypointTheme.urgent
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 28
            Layout.bottomMargin: 12

            Text {
                text: root.controller.todayTasks.overdueCount > 0 ? root.controller.todayTasks.overdueCount + " atrasada" + (root.controller.todayTasks.overdueCount === 1 ? "" : "s") : root.controller.todayTasks.pendingCount + " pendente" + (root.controller.todayTasks.pendingCount === 1 ? "" : "s")
                color: root.controller.todayTasks.overdueCount > 0 ? WaypointTheme.urgent : WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
                font.bold: true
                font.letterSpacing: 1
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                visible: !root.compact
                text: "N  NOVA TAREFA"
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
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
            Layout.topMargin: 12
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
                    color: WaypointTheme.disabledText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.subtitleSize
                }
            }
        }
    }

    Shortcut {
        sequence: "N"
        onActivated: composer.focusInput()
    }
}
