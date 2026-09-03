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

    function recordHabit(habit) {
        if (habit.checkInMode === "manual") {
            manualHabit = habit;
            manualAmount.value = 1;
            manualPopup.open();
        } else {
            controller.recordHabit(habit.id, 0);
        }
    }

    property var manualHabit: ({})

    TaskEditor {
        id: taskEditor
        controller: root.controller
    }

    Popup {
        id: manualPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 420)
        modal: true
        focus: true
        padding: 16
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle {
            color: MobileTheme.scrim
        }

        background: Rectangle {
            radius: MobileTheme.radius
            color: MobileTheme.panel
            border.width: 1
            border.color: MobileTheme.accent
        }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Registrar " + (root.manualHabit.title || "hábito")
                color: MobileTheme.foreground
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.titleSize
                font.bold: true
                wrapMode: Text.Wrap
            }

            SpinBox {
                id: manualAmount
                Layout.fillWidth: true
                implicitHeight: MobileTheme.touchHeight
                from: 1
                to: 1000000000
                editable: true
            }

            RowLayout {
                Layout.fillWidth: true

                MobileButton {
                    text: "CANCELAR"
                    quiet: true
                    onClicked: manualPopup.close()
                }

                Item {
                    Layout.fillWidth: true
                }

                MobileButton {
                    text: "REGISTRAR"
                    accent: true
                    onClicked: {
                        if (root.controller.recordHabit(root.manualHabit.id, manualAmount.value))
                            manualPopup.close();
                    }
                }
            }
        }
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
                    text: Qt.locale().toString(root.now, "dddd, d MMMM")
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
                    text: root.controller.syncState === "ready" ? "SYNC" : root.controller.syncConfigured ? "LOCAL" : "OFFLINE"
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
                                                  ? MobileTheme.urgent : MobileTheme.border
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
                                                                      : MobileTheme.foreground
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.bodySize
                                    font.strikeout: taskRow.modelData.completed
                                    wrapMode: Text.Wrap
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
                    text: "Nenhuma tarefa pendente."
                    color: MobileTheme.disabled
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10

                    Text {
                        text: "HÁBITOS"
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
                        text: root.controller.todayHabits.length + " hoje"
                        color: MobileTheme.disabled
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.captionSize
                    }
                }

                Repeater {
                    model: root.controller.todayHabits

                    delegate: Rectangle {
                        id: habitRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Math.max(62, habitContent.implicitHeight + 16)
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: MobileTheme.divider
                        }

                        RowLayout {
                            id: habitContent
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 2
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 9

                            Text {
                                text: habitRow.modelData.emoji || "◌"
                                color: MobileTheme.foreground
                                font.pixelSize: 18
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        Layout.fillWidth: true
                                        text: habitRow.modelData.title
                                        Accessible.name: text
                                        color: MobileTheme.foreground
                                        font.family: MobileTheme.fontFamily
                                        font.pixelSize: MobileTheme.bodySize
                                        font.bold: true
                                        wrapMode: Text.Wrap
                                    }

                                    Text {
                                        text: habitRow.modelData.amount + " / " + habitRow.modelData.targetAmount
                                        color: habitRow.modelData.completed ? MobileTheme.success : MobileTheme.subdued
                                        font.family: MobileTheme.fontFamily
                                        font.pixelSize: MobileTheme.captionSize
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    radius: 2
                                    color: MobileTheme.surfaceRaised

                                    Rectangle {
                                        width: parent.width * Math.min(1, habitRow.modelData.amount / habitRow.modelData.targetAmount)
                                        height: parent.height
                                        radius: parent.radius
                                        color: habitRow.modelData.completed ? MobileTheme.success : MobileTheme.accent
                                    }
                                }
                            }

                            Button {
                                id: undoButton
                                visible: habitRow.modelData.amount > 0
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                padding: 11
                                Accessible.id: "habit-undo-" + habitRow.modelData.id
                                Accessible.name: "Desfazer último registro de " + habitRow.modelData.title
                                onClicked: root.controller.undoHabit(habitRow.modelData.id)

                                background: Rectangle {
                                    radius: MobileTheme.radius
                                    color: undoButton.down ? MobileTheme.surfacePressed : "transparent"
                                }

                                contentItem: MobileIcon {
                                    name: "undo"
                                    color: MobileTheme.subdued
                                }
                            }

                            MobileButton {
                                Layout.preferredWidth: 44
                                text: habitRow.modelData.completed ? "✓" : "+"
                                accent: !habitRow.modelData.completed
                                enabled: !habitRow.modelData.completed
                                Accessible.id: "habit-check-in-" + habitRow.modelData.id
                                Accessible.name: habitRow.modelData.completed ? "Hábito concluído " + habitRow.modelData.title : "Registrar hábito " + habitRow.modelData.title
                                onClicked: root.recordHabit(habitRow.modelData)
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: 18
                }
            }
        }
    }
}
