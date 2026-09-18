pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var controller
    required property var habits
    required property string dateKey
    property var manualHabit: ({})

    spacing: 0

    function recordHabit(habit) {
        if (habit.checkInMode === "manual") {
            manualHabit = habit;
            manualAmount.value = 1;
            manualPopup.open();
        } else {
            controller.recordHabit(habit.id, dateKey, 0);
        }
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
                        if (root.controller.recordHabit(
                                root.manualHabit.id, root.dateKey, manualAmount.value))
                            manualPopup.close();
                    }
                }
            }
        }
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
            text: root.habits.length + " neste dia"
            color: MobileTheme.disabled
            font.family: MobileTheme.fontFamily
            font.pixelSize: MobileTheme.captionSize
        }
    }

    Repeater {
        model: root.habits

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
                            width: parent.width * Math.min(
                                       1, habitRow.modelData.amount / habitRow.modelData.targetAmount)
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
                    onClicked: root.controller.undoHabit(habitRow.modelData.id, root.dateKey)

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
                    Accessible.name: habitRow.modelData.completed
                                     ? "Hábito concluído " + habitRow.modelData.title
                                     : "Registrar hábito " + habitRow.modelData.title
                    onClicked: root.recordHabit(habitRow.modelData)
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.habits.length === 0
        text: "Nenhum hábito programado neste dia."
        color: MobileTheme.disabled
        font.family: MobileTheme.fontFamily
        font.pixelSize: MobileTheme.bodySize
        horizontalAlignment: Text.AlignHCenter
        Layout.topMargin: 10
        Layout.bottomMargin: 10
    }
}
