pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    readonly property bool compact: width < WaypointTheme.compactBreakpoint
    readonly property var tasks: controller.todayTasks
    readonly property int completedCount: Math.max(0, taskList.count - tasks.pendingCount - tasks.skippedCount)

    CompletionActions {
        id: completionFlow
        controller: root.controller
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 20 : 32
        anchors.rightMargin: root.compact ? 20 : 32
        anchors.topMargin: root.compact ? 20 : 28
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                spacing: 4

                Text {
                    text: "Hoje"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: root.compact ? WaypointTheme.displaySize : WaypointTheme.displayLargeSize
                    font.weight: WaypointTheme.weightSemiBold
                }

                RowLayout {
                    spacing: 0

                    Text {
                        text: Qt.locale("pt_BR").toString(new Date(), "dddd, d 'de' MMMM") + " · "
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }

                    Text {
                        text: root.tasks.overdueCount > 0
                              ? root.tasks.overdueCount + " atrasada" + (root.tasks.overdueCount === 1 ? "" : "s")
                              : root.tasks.pendingCount + " pendente" + (root.tasks.pendingCount === 1 ? "" : "s")
                        color: root.tasks.overdueCount > 0 ? WaypointTheme.urgent : WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                        font.weight: root.tasks.overdueCount > 0 ? WaypointTheme.weightMedium : Font.Normal
                    }
                }
            }

            Item { Layout.fillWidth: true }

            TaskVisibilityChip {
                controller: root.controller
            }
        }

        QuickTaskComposer {
            id: composer
            Layout.fillWidth: true
            Layout.topMargin: 20
            controller: root.controller
            scheduledDateKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
            placeholderText: "Adicionar tarefa"
        }

        ScrollView {
            id: dayScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 16
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: dayScroll.availableWidth
                spacing: 20

                Rectangle {
                    visible: taskList.count > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: taskList.contentHeight + 8
                    radius: WaypointTheme.radiusLarge
                    color: WaypointTheme.surface
                    border.width: 1
                    border.color: WaypointTheme.controlBorder

                    ListView {
                        id: taskList
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        interactive: false
                        model: root.tasks
                        section.property: "completed"
                        section.delegate: Item {
                            id: sectionHeader
                            required property string section
                            width: taskList.width
                            height: section === "true" && root.completedCount > 0 ? 40 : 0
                            visible: height > 0

                            Rectangle {
                                visible: sectionHeader.y > 0
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                height: 1
                                color: WaypointTheme.divider
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: "Concluídas · " + root.completedCount
                                color: WaypointTheme.disabledText
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.captionSize
                                font.weight: WaypointTheme.weightMedium
                            }
                        }

                        delegate: TaskRow {
                            required property int index
                            width: taskList.width
                            showDivider: index > 0 && ListView.previousSection === ListView.section
                            controller: root.controller
                            completionActions: completionFlow
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    visible: taskList.count === 0
                    text: root.controller.taskVisibility === "pending"
                        ? "Nenhuma tarefa pendente." : "Seu dia está livre."
                    horizontalAlignment: Text.AlignHCenter
                    color: WaypointTheme.disabledText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySize
                }

                RegistrationActivity {
                    Layout.fillWidth: true
                    groups: root.controller.todayRegistrationActivity
                    dateKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
                    completionActions: completionFlow
                }

                HabitSection {
                    Layout.fillWidth: true
                    controller: root.controller
                    habits: root.controller.todayHabits
                    dateKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
                }

                Item { Layout.preferredHeight: 12 }
            }
        }
    }

    Shortcut {
        sequence: "N"
        onActivated: composer.focusInput()
    }
}
