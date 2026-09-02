pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    required property var controller
    property var editingHabit: ({})
    property var selectedWeekdays: [1, 2, 3, 4, 5, 6, 7]
    property var reminderTimes: []

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: 0

    function modeIndex(value) {
        return Math.max(0, ["complete", "fixed", "manual"].indexOf(value));
    }

    function toggleWeekday(day) {
        let next = selectedWeekdays.slice();
        const index = next.indexOf(day);
        if (index < 0)
            next.push(day);
        else
            next.splice(index, 1);
        next.sort();
        selectedWeekdays = next;
    }

    function addReminder() {
        const value = reminderField.text.trim();
        if (!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(value) || reminderTimes.indexOf(value) >= 0)
            return;
        let next = reminderTimes.slice();
        next.push(value);
        next.sort();
        reminderTimes = next;
        reminderField.text = "";
    }

    function removeReminder(value) {
        let next = reminderTimes.slice();
        const index = next.indexOf(value);
        if (index >= 0)
            next.splice(index, 1);
        reminderTimes = next;
    }

    function openForCreate() {
        editingHabit = ({});
        emojiField.text = "";
        titleField.text = "";
        targetField.value = 1;
        unitField.text = "vez";
        modeField.currentIndex = 0;
        incrementField.value = 1;
        selectedWeekdays = [1, 2, 3, 4, 5, 6, 7];
        reminderTimes = [];
        open();
        titleField.forceActiveFocus();
    }

    function openForEdit(habit) {
        editingHabit = habit;
        emojiField.text = habit.emoji || "";
        titleField.text = habit.title || "";
        targetField.value = habit.targetAmount || 1;
        unitField.text = habit.unit || "";
        modeField.currentIndex = modeIndex(habit.checkInMode || "complete");
        incrementField.value = habit.incrementAmount || 1;
        selectedWeekdays = habit.weekdays || [];
        reminderTimes = habit.reminderTimes || [];
        open();
        titleField.forceActiveFocus();
    }

    function save() {
        const modes = ["complete", "fixed", "manual"];
        const succeeded = controller.saveHabit(editingHabit.id || "", titleField.text, targetField.value, unitField.text, modes[modeField.currentIndex], incrementField.value, selectedWeekdays, reminderTimes, emojiField.text);
        if (succeeded)
            close();
    }

    Overlay.modal: Rectangle {
        color: MobileTheme.scrim
    }

    background: Rectangle {
        color: MobileTheme.background
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            color: MobileTheme.background

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: MobileTheme.divider
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: MobileTheme.pageMargin
                anchors.rightMargin: MobileTheme.pageMargin
                spacing: 8

                MobileButton {
                    Layout.preferredWidth: 44
                    text: "‹"
                    quiet: true
                    Accessible.name: "Fechar editor de hábito"
                    onClicked: root.close()
                }

                Text {
                    Layout.fillWidth: true
                    text: root.editingHabit.id ? "Editar hábito" : "Novo hábito"
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.titleSize
                    font.bold: true
                    elide: Text.ElideRight
                }

                MobileButton {
                    Layout.preferredWidth: 86
                    text: "SALVAR"
                    accent: true
                    Accessible.id: "habit-editor-save"
                    enabled: titleField.text.trim().length > 0 && root.selectedWeekdays.length > 0
                    onClicked: root.save()
                }
            }
        }

        ScrollView {
            id: editorScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: Math.max(0, editorScroll.availableWidth - MobileTheme.pageMargin * 2)
                x: MobileTheme.pageMargin
                spacing: 12

                Item {
                    Layout.preferredHeight: 4
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileField {
                        id: emojiField
                        Layout.preferredWidth: 62
                        placeholderText: "◉"
                        maximumLength: 8
                    }

                    MobileField {
                        id: titleField
                        Layout.fillWidth: true
                        placeholderText: "Nome do hábito"
                        Accessible.id: "habit-editor-title"
                        Accessible.name: "Nome do hábito"
                        onAccepted: root.save()
                    }
                }

                Text {
                    text: "META DIÁRIA"
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SpinBox {
                        id: targetField
                        Layout.preferredWidth: 126
                        implicitHeight: MobileTheme.touchHeight
                        from: 1
                        to: 1000000000
                        editable: true
                    }

                    MobileField {
                        id: unitField
                        Layout.fillWidth: true
                        placeholderText: "unidade"
                    }
                }

                MobileComboBox {
                    id: modeField
                    Layout.fillWidth: true
                    implicitHeight: MobileTheme.touchHeight
                    model: ["Concluir de uma vez", "Somar quantidade fixa", "Informar quantidade"]
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: modeField.currentIndex === 1

                    Text {
                        text: "Cada registro soma"
                        color: MobileTheme.subdued
                        font.family: MobileTheme.fontFamily
                        font.pixelSize: MobileTheme.bodySize
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    SpinBox {
                        id: incrementField
                        Layout.preferredWidth: 126
                        implicitHeight: MobileTheme.touchHeight
                        from: 1
                        to: 1000000000
                        editable: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: MobileTheme.divider
                }

                Text {
                    text: "DIAS DA SEMANA"
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ["S", "T", "Q", "Q", "S", "S", "D"]
                        delegate: Button {
                            id: weekdayButton
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 40
                            text: modelData
                            onClicked: root.toggleWeekday(weekdayButton.index + 1)
                            background: Rectangle {
                                radius: MobileTheme.radius
                                color: root.selectedWeekdays.indexOf(weekdayButton.index + 1) >= 0 ? MobileTheme.surfaceSelected : MobileTheme.surfaceRaised
                                border.width: 1
                                border.color: root.selectedWeekdays.indexOf(weekdayButton.index + 1) >= 0 ? MobileTheme.activeBorder : MobileTheme.border
                            }
                            contentItem: Text {
                                text: weekdayButton.text
                                color: MobileTheme.foreground
                                font.family: MobileTheme.fontFamily
                                font.pixelSize: MobileTheme.bodySize
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: MobileTheme.divider
                }

                Text {
                    text: "HORÁRIOS DE LEMBRETE"
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileField {
                        id: reminderField
                        Layout.fillWidth: true
                        placeholderText: "HH:mm"
                        inputMethodHints: Qt.ImhTime
                        onAccepted: root.addReminder()
                    }

                    MobileButton {
                        text: "ADICIONAR"
                        onClicked: root.addReminder()
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.reminderTimes
                        delegate: MobileButton {
                            required property string modelData
                            text: modelData + "  ×"
                            quiet: true
                            onClicked: root.removeReminder(modelData)
                        }
                    }
                }

                MobileButton {
                    Layout.fillWidth: true
                    visible: !!root.editingHabit.id
                    text: "EXCLUIR HÁBITO"
                    destructive: true
                    onClicked: {
                        if (root.controller.deleteHabit(root.editingHabit.id))
                            root.close();
                    }
                }

                Item {
                    Layout.preferredHeight: 16
                }
            }
        }
    }
}
