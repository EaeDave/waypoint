pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller

    function todayProgress(habitId) {
        for (const progress of controller.todayHabits) {
            if (progress.id === habitId)
                return progress;
        }
        return null;
    }

    function weekdayLabel(days) {
        if (!days || days.length === 7)
            return "Todos os dias";
        const names = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"];
        let labels = [];
        for (const day of days)
            labels.push(names[day - 1]);
        return labels.join(" · ");
    }

    HabitEditor {
        id: habitEditor
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
                    text: "Hábitos"
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.displaySize
                    font.bold: true
                }

                Text {
                    text: root.controller.allHabits.length + " ritmo" + (root.controller.allHabits.length === 1 ? "" : "s")
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySmallSize
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        MobileButton {
            Layout.fillWidth: true
            text: "+  NOVO HÁBITO…"
            Accessible.id: "create-habit"
            onClicked: habitEditor.openForCreate()
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
                    model: root.controller.allHabits

                    delegate: Rectangle {
                        id: habitRow
                        required property var modelData
                        readonly property var progress: root.todayProgress(habitRow.modelData.id)
                        Layout.fillWidth: true
                        implicitHeight: habitContent.implicitHeight + 20
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: MobileTheme.divider
                        }

                        ColumnLayout {
                            id: habitContent
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 2
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 9

                                Text {
                                    text: habitRow.modelData.emoji || "◌"
                                    color: MobileTheme.foreground
                                    font.pixelSize: 20
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

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
                                        Layout.fillWidth: true
                                        text: habitRow.modelData.targetAmount + " " + habitRow.modelData.unit + "  ·  " + root.weekdayLabel(habitRow.modelData.weekdays)
                                        color: MobileTheme.subdued
                                        font.family: MobileTheme.fontFamily
                                        font.pixelSize: MobileTheme.captionSize
                                        elide: Text.ElideRight
                                    }
                                }

                                MobileButton {
                                    Layout.preferredWidth: 44
                                    text: "···"
                                    quiet: true
                                    onClicked: habitEditor.openForEdit(habitRow.modelData)
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                visible: !!habitRow.progress
                                Layout.preferredHeight: 4
                                radius: 2
                                color: MobileTheme.surfaceRaised

                                Rectangle {
                                    width: parent.width * Math.min(1, habitRow.progress ? habitRow.progress.amount / habitRow.modelData.targetAmount : 0)
                                    height: parent.height
                                    radius: parent.radius
                                    color: habitRow.progress && habitRow.progress.completed ? MobileTheme.success : MobileTheme.accent
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    visible: !!habitRow.progress
                                    text: habitRow.progress ? habitRow.progress.amount + " / " + habitRow.modelData.targetAmount + " hoje" : ""
                                    color: habitRow.progress && habitRow.progress.completed ? MobileTheme.success : MobileTheme.subdued
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.captionSize
                                }

                                Text {
                                    visible: !habitRow.progress
                                    text: "NÃO AGENDADO HOJE"
                                    color: MobileTheme.disabled
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.captionSize
                                    font.letterSpacing: 0.6
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    visible: habitRow.modelData.reminderTimes.length > 0
                                    spacing: 4

                                    MobileIcon {
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        name: "clock"
                                        color: MobileTheme.subdued
                                    }

                                    Text {
                                        text: habitRow.modelData.reminderTimes.join("  ")
                                        color: MobileTheme.subdued
                                        font.family: MobileTheme.fontFamily
                                        font.pixelSize: MobileTheme.captionSize
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.controller.allHabits.length === 0
                    text: "Crie seu primeiro hábito."
                    color: MobileTheme.disabled
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 24
                }

                Item {
                    Layout.preferredHeight: 16
                }
            }
        }
    }
}
