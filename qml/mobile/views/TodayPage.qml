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


    TaskEditor {
        id: taskEditor
        controller: root.controller
    }


    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: MobileTheme.pageMargin
        anchors.rightMargin: MobileTheme.pageMargin
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 18

            ColumnLayout {
                spacing: 3

                Text {
                    text: "Hoje"
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.displaySize
                    font.bold: true
                }

                Text {
                    text: Qt.locale("pt_BR").toString(root.now, "dddd, d 'de' MMMM")
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySmallSize
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: syncLabel.implicitWidth + 18
                Layout.preferredHeight: 28
                radius: MobileTheme.radius
                color: MobileTheme.surfaceRaised
                border.width: 1
                border.color: root.controller.syncState === "ready" ? MobileTheme.success : root.controller.syncState === "error" ? MobileTheme.urgent : MobileTheme.divider

                Text {
                    id: syncLabel
                    anchors.centerIn: parent
                    text: root.controller.syncState === "ready" ? "SINC." : root.controller.syncConfigured ? "LOCAL" : "SEM REDE"
                    color: root.controller.syncState === "ready" ? MobileTheme.success : root.controller.syncState === "error" ? MobileTheme.urgent : MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 0.8
                }
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

        MobileButton {
            Layout.fillWidth: true
            text: "+  NOVA TAREFA…"
            Accessible.id: "create-task"
            onClicked: taskEditor.openForCreate(root.controller.todayKey)
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "TAREFAS"
                        color: MobileTheme.subdued
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.captionSize
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.controller.todayTasks.length
                        color: MobileTheme.disabled
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.captionSize
                    }

                    TaskVisibilityChip {
                        controller: root.controller
                    }
                }


                Repeater {
                    model: root.controller.todayTasks

                    delegate: Rectangle {
                        id: taskRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Math.max(58, taskContent.implicitHeight + 16)
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: MobileTheme.divider
                        }

                        Rectangle {
                            visible: taskRow.modelData.categoryName !== ""
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 3
                            radius: 1
                            color: taskRow.modelData.categoryColor
                        }

                        RowLayout {
                            id: taskContent
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 2
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 9

                            Button {
                                id: completionButton
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                text: taskRow.modelData.completed ? "✓"
                                    : taskRow.modelData.skipped ? "×" : ""
                                Accessible.id: "task-completion-" + taskRow.modelData.taskId
                                Accessible.name: taskRow.modelData.completed
                                    ? "Reabrir tarefa " + taskRow.modelData.title
                                    : taskRow.modelData.skipped
                                      ? "Reabrir ocorrência " + taskRow.modelData.title
                                      : "Concluir tarefa " + taskRow.modelData.title
                                onClicked: root.controller.setTaskCompleted(
                                               taskRow.modelData.taskId,
                                               taskRow.modelData.occurrenceDate,
                                               taskRow.modelData.recurring,
                                               taskRow.modelData.skipped ? false
                                                                           : !taskRow.modelData.completed)
                                background: Rectangle {
                                    radius: MobileTheme.radius
                                    color: taskRow.modelData.completed ? MobileTheme.success
                                         : taskRow.modelData.skipped ? MobileTheme.urgent : "transparent"
                                    border.width: 1
                                    border.color: taskRow.modelData.completed ? MobileTheme.success
                                                : taskRow.modelData.skipped
                                                  || taskRow.modelData.occurrenceDate < root.controller.todayKey
                                                  ? MobileTheme.urgent
                                                  : taskRow.modelData.categoryName !== ""
                                                    ? taskRow.modelData.categoryColor
                                                    : MobileTheme.border
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
                                    Accessible.name: text
                                    color: taskRow.modelData.completed ? MobileTheme.disabled
                                         : taskRow.modelData.skipped ? MobileTheme.urgent
                                         : taskRow.modelData.categoryName !== ""
                                           ? taskRow.modelData.categoryColor
                                           : MobileTheme.foreground
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.bodySize
                                    font.strikeout: taskRow.modelData.completed
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    visible: taskRow.modelData.categoryName !== ""
                                    text: taskRow.modelData.categoryName.toUpperCase()
                                    elide: Text.ElideRight
                                    color: taskRow.modelData.completed
                                           ? MobileTheme.disabled : taskRow.modelData.categoryColor
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.captionSize
                                    font.bold: true
                                    font.letterSpacing: 0.6
                                }

                                Text {
                                    text: taskRow.modelData.scheduledTime
                                          + (taskRow.modelData.recurrenceLabel
                                             ? "  ·  " + taskRow.modelData.recurrenceLabel : "")
                                          + (taskRow.modelData.skipped
                                             ? "  ·  NÃO FEITA"
                                             : taskRow.modelData.occurrenceDate < root.controller.todayKey
                                               && !taskRow.modelData.completed ? "  ·  ATRASADA" : "")
                                    color: taskRow.modelData.skipped
                                           || (taskRow.modelData.occurrenceDate < root.controller.todayKey
                                               && !taskRow.modelData.completed)
                                         ? MobileTheme.urgent : MobileTheme.subdued
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
                    visible: root.controller.todayTasks.length === 0
                    text: root.controller.taskVisibility === "pending"
                          ? "Nenhuma tarefa pendente." : "Nenhuma tarefa para hoje."
                    color: MobileTheme.disabled
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                }

                HabitProgressSection {
                    Layout.fillWidth: true
                    controller: root.controller
                    habits: root.controller.todayHabits
                    dateKey: root.controller.todayKey
                }

                Item {
                    Layout.preferredHeight: 18
                }
            }
        }
    }
}
