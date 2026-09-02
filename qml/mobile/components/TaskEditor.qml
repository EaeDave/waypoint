pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    required property var controller
    property var editingTask: ({})
    property var selectedWeekdays: []
    property var selectedReminders: [0]

    parent: Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: 0

    function frequencyIndex(value) {
        const values = ["none", "daily", "weekly", "monthly", "yearly"];
        return Math.max(0, values.indexOf(value));
    }

    function endIndex(value) {
        const values = ["never", "onDate", "afterCount"];
        return Math.max(0, values.indexOf(value));
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

    function toggleReminder(minutes) {
        let next = selectedReminders.slice();
        const index = next.indexOf(minutes);
        if (index < 0)
            next.push(minutes);
        else
            next.splice(index, 1);
        next.sort((a, b) => a - b);
        selectedReminders = next;
    }

    function openForCreate(dateKey) {
        editingTask = ({});
        emojiField.text = "";
        titleField.text = "";
        dateField.text = dateKey;
        timeField.text = Qt.formatTime(new Date(), "HH:mm");
        frequencyField.currentIndex = 0;
        intervalField.value = 1;
        selectedWeekdays = [];
        endField.currentIndex = 0;
        untilField.text = dateKey;
        countField.value = 10;
        selectedReminders = [0];
        open();
        titleField.forceActiveFocus();
    }

    function openForEdit(task) {
        editingTask = task;
        const recurrence = task.recurrence || {};
        emojiField.text = task.emoji || "";
        titleField.text = task.title || "";
        dateField.text = task.scheduledDate || task.occurrenceDate || "";
        timeField.text = task.scheduledTime || "";
        frequencyField.currentIndex = frequencyIndex(recurrence.frequency || "none");
        intervalField.value = recurrence.interval || 1;
        selectedWeekdays = recurrence.weekdays || [];
        endField.currentIndex = endIndex(recurrence.endMode || "never");
        untilField.text = recurrence.untilDate || dateField.text;
        countField.value = recurrence.occurrenceCount || 10;
        selectedReminders = task.reminderMinutesBefore || [];
        open();
        titleField.forceActiveFocus();
    }

    function save() {
        const frequencies = ["none", "daily", "weekly", "monthly", "yearly"];
        const ends = ["never", "onDate", "afterCount"];
        const succeeded = controller.saveTask(editingTask.taskId || "", titleField.text, dateField.text, timeField.text, frequencies[frequencyField.currentIndex], intervalField.value, selectedWeekdays, ends[endField.currentIndex], untilField.text, countField.value, selectedReminders, emojiField.text);
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
                    Accessible.name: "Fechar editor de tarefa"
                    onClicked: root.close()
                }

                Text {
                    Layout.fillWidth: true
                    text: root.editingTask.taskId ? "Editar tarefa" : "Nova tarefa"
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
                    Accessible.id: "task-editor-save"
                    enabled: titleField.text.trim().length > 0
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
                        placeholderText: "O que precisa acontecer?"
                        Accessible.id: "task-editor-title"
                        Accessible.name: "Título da tarefa"
                        onAccepted: root.save()
                    }
                }

                Text {
                    text: "DATA E HORA"
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
                        id: dateField
                        Layout.fillWidth: true
                        placeholderText: "YYYY-MM-DD"
                        inputMethodHints: Qt.ImhDate
                    }

                    MobileField {
                        id: timeField
                        Layout.preferredWidth: 100
                        placeholderText: "HH:mm"
                        inputMethodHints: Qt.ImhTime
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: MobileTheme.divider
                }

                Text {
                    text: "REPETIÇÃO"
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MobileComboBox {
                        id: frequencyField
                        Layout.fillWidth: true
                        implicitHeight: MobileTheme.touchHeight
                        model: ["Não repete", "Diária", "Semanal", "Mensal", "Anual"]
                    }

                    SpinBox {
                        id: intervalField
                        Layout.preferredWidth: 104
                        implicitHeight: MobileTheme.touchHeight
                        from: 1
                        to: 365
                        editable: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: frequencyField.currentIndex === 2
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

                MobileComboBox {
                    id: endField
                    Layout.fillWidth: true
                    visible: frequencyField.currentIndex > 0
                    implicitHeight: MobileTheme.touchHeight
                    model: ["Sem término", "Até uma data", "Após ocorrências"]
                }

                MobileField {
                    id: untilField
                    Layout.fillWidth: true
                    visible: frequencyField.currentIndex > 0 && endField.currentIndex === 1
                    placeholderText: "Última data YYYY-MM-DD"
                    inputMethodHints: Qt.ImhDate
                }

                SpinBox {
                    id: countField
                    Layout.fillWidth: true
                    visible: frequencyField.currentIndex > 0 && endField.currentIndex === 2
                    implicitHeight: MobileTheme.touchHeight
                    from: 1
                    to: 10000
                    editable: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: MobileTheme.divider
                }

                Text {
                    text: "LEMBRAR"
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.captionSize
                    font.bold: true
                    font.letterSpacing: 1
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            {
                                value: 0,
                                label: "Na hora"
                            },
                            {
                                value: 10,
                                label: "10 min"
                            },
                            {
                                value: 30,
                                label: "30 min"
                            },
                            {
                                value: 60,
                                label: "1 hora"
                            },
                            {
                                value: 1440,
                                label: "1 dia"
                            }
                        ]
                        delegate: MobileCheck {
                            required property var modelData
                            text: modelData.label
                            checked: root.selectedReminders.indexOf(modelData.value) >= 0
                            onClicked: root.toggleReminder(modelData.value)
                        }
                    }
                }

                MobileButton {
                    Layout.fillWidth: true
                    visible: !!root.editingTask.taskId
                    text: "EXCLUIR TAREFA"
                    destructive: true
                    onClicked: {
                        if (root.controller.deleteTask(root.editingTask.taskId))
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
