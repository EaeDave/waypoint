pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    required property string taskId
    required property string title
    required property string scheduledDateKey
    required property string scheduledTimeKey
    required property bool completed
    required property bool overdue
    required property bool recurring
    required property string recurrenceLabel
    required property var recurrence
    required property var controller
    property int weekdayMask: 0

    readonly property date scheduledDateValue: {
        const parts = scheduledDateKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    implicitHeight: root.overdue || root.recurring ? 62 : 50
    radius: 7
    color: pointer.containsMouse ? "#151519" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: 4
            color: root.completed ? "#a997ff" : "transparent"
            border.width: 1
            border.color: root.completed ? "#a997ff" : (root.overdue ? "#ff7085" : "#77737e")

            Text {
                anchors.centerIn: parent
                visible: root.completed
                text: "✓"
                color: "#0a090c"
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.controller.setOccurrenceCompleted(root.taskId,
                                                                   root.scheduledDateKey,
                                                                   !root.completed)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.completed ? "#716e77" : "#f2f0f5"
                elide: Text.ElideRight
                font.family: "sans-serif"
                font.pixelSize: 14
                font.strikeout: root.completed
            }

            Text {
                visible: root.overdue || root.recurring
                text: {
                    const recurrence = root.recurring ? root.recurrenceLabel : "";
                    if (!root.overdue)
                        return recurrence;
                    const overdue = "ATRASADA · " + Qt.formatDate(root.scheduledDateValue, "dd MMM");
                    return recurrence === "" ? overdue : overdue + " · " + recurrence;
                }
                color: root.overdue ? "#ff7085" : "#a997ff"
                font.family: "monospace"
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1
            }
        }

        Text {
            text: root.scheduledTimeKey
            color: root.completed ? "#716e77" : "#d7d3dc"
            font.family: "monospace"
            font.pixelSize: 11
        }

        ToolButton {
            id: taskActions
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            text: "⋯"
            onClicked: actionsMenu.open()
            ToolTip.visible: hovered
            ToolTip.text: "Editar ou excluir tarefa"

            background: Rectangle {
                radius: 5
                color: taskActions.hovered ? "#24212c" : "transparent"
                border.width: 1
                border.color: taskActions.hovered || taskActions.activeFocus ? "#a997ff" : "#4b4752"
            }

            Menu {
                id: actionsMenu

                MenuItem {
                    text: "Editar"
                    onTriggered: root.openEditor()
                }
                MenuSeparator {}
                MenuItem {
                    visible: !root.recurring
                    text: "Excluir tarefa"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "series")
                }
                MenuItem {
                    visible: root.recurring
                    text: "Excluir esta ocorrência"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "occurrence")
                }
                MenuItem {
                    visible: root.recurring
                    text: "Excluir esta e as seguintes"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "following")
                }
                MenuItem {
                    visible: root.recurring
                    text: "Excluir toda a série"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "series")
                }
            }
        }
    }

    function anchorWeekdayIndex() {
        return (root.scheduledDateValue.getDay() + 6) % 7;
    }

    function recurrencePresetIndex() {
        const frequency = String(root.recurrence.frequency || "none");
        if (frequency === "none")
            return 0;
        const standard = Number(root.recurrence.interval || 1) === 1
                      && (root.recurrence.weekdays || []).length === 0
                      && String(root.recurrence.endMode || "never") === "never";
        if (!standard)
            return 5;
        return frequency === "daily" ? 1
             : frequency === "weekly" ? 2
             : frequency === "monthly" ? 3 : 4;
    }

    function selectedFrequency() {
        if (recurrenceInput.currentIndex === 5)
            return customFrequency.currentValue;
        return recurrenceInput.currentValue;
    }

    function selectedWeekdays() {
        if (recurrenceInput.currentIndex !== 5 || customFrequency.currentValue !== "weekly")
            return [];
        const selected = [];
        for (let index = 0; index < 7; ++index) {
            if ((root.weekdayMask & (1 << index)) !== 0)
                selected.push(index + 1);
        }
        return selected;
    }

    function openEditor() {
        editTitle.text = root.title;
        editTime.text = root.scheduledTimeKey;
        const frequency = String(root.recurrence.frequency || "none");
        customFrequency.currentIndex = Math.max(
            0, customFrequency.indexOfValue(frequency === "none" ? "daily" : frequency));
        customInterval.value = Number(root.recurrence.interval || 1);
        root.weekdayMask = 0;
        for (const weekday of (root.recurrence.weekdays || []))
            root.weekdayMask |= 1 << (Number(weekday) - 1);
        if (frequency === "weekly" && root.weekdayMask === 0)
            root.weekdayMask = 1 << root.anchorWeekdayIndex();
        customEnding.currentIndex = Math.max(
            0, customEnding.indexOfValue(String(root.recurrence.endMode || "never")));
        customUntilDate.text = String(root.recurrence.untilDate || root.scheduledDateKey);
        customOccurrenceCount.value = Math.max(1, Number(root.recurrence.occurrenceCount || 10));
        recurrenceInput.currentIndex = root.recurrencePresetIndex();
        editPopup.open();
        editTitle.forceActiveFocus();
        editTitle.selectAll();
    }

    function saveEdit() {
        const normalizedTitle = editTitle.text.trim();
        const normalizedTime = editTime.text.trim();
        if (normalizedTitle === "" || !editTime.acceptableInput)
            return;

        const custom = recurrenceInput.currentIndex === 5;
        const frequency = root.selectedFrequency();
        const endMode = custom ? customEnding.currentValue : "never";
        if (root.controller.editTask(
                root.taskId, normalizedTitle, normalizedTime, frequency,
                custom ? customInterval.value : 1, root.selectedWeekdays(), endMode,
                endMode === "onDate" ? customUntilDate.text.trim() : "",
                endMode === "afterCount" ? customOccurrenceCount.value : 0))
            editPopup.close();
    }

    Popup {
        id: editPopup
        x: Math.max(0, root.width - width)
        y: root.height + 4
        width: 390
        padding: 16
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 9
            color: "#17161b"
            border.width: 1
            border.color: "#34313b"
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: "EDITAR TAREFA"
                color: "#aaa7ad"
                font.family: "monospace"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            TextField {
                id: editTitle
                Layout.fillWidth: true
                placeholderText: "Título"
                selectByMouse: true
                onAccepted: editTime.forceActiveFocus()
            }

            TextField {
                id: editTime
                Layout.fillWidth: true
                placeholderText: "HH:mm"
                selectByMouse: true
                inputMethodHints: Qt.ImhTime
                validator: RegularExpressionValidator {
                    regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
                }
                onAccepted: root.saveEdit()
            }

            ComboBox {
                id: recurrenceInput
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "Não repetir", value: "none" },
                    { text: "Diariamente", value: "daily" },
                    { text: "Semanalmente", value: "weekly" },
                    { text: "Mensalmente", value: "monthly" },
                    { text: "Anualmente", value: "yearly" },
                    { text: "Personalizado", value: "custom" }
                ]
            }

            GridLayout {
                visible: recurrenceInput.currentIndex === 5
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 9

                Label {
                    text: "Frequência"
                }
                ComboBox {
                    id: customFrequency
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Diária", value: "daily" },
                        { text: "Semanal", value: "weekly" },
                        { text: "Mensal", value: "monthly" },
                        { text: "Anual", value: "yearly" }
                    ]
                    onCurrentValueChanged: {
                        if (currentValue === "weekly" && root.weekdayMask === 0)
                            root.weekdayMask = 1 << root.anchorWeekdayIndex();
                    }
                }

                Label {
                    text: "A cada"
                }
                RowLayout {
                    SpinBox {
                        id: customInterval
                        from: 1
                        to: 99
                        value: 1
                    }
                    Label {
                        text: customFrequency.currentValue === "daily" ? "dia(s)"
                            : customFrequency.currentValue === "weekly" ? "semana(s)"
                            : customFrequency.currentValue === "monthly" ? "mês(es)" : "ano(s)"
                    }
                }

                Label {
                    text: "Somente em"
                    visible: customFrequency.currentValue === "weekly"
                }
                RowLayout {
                    visible: customFrequency.currentValue === "weekly"
                    spacing: 2
                    Repeater {
                        model: ["S", "T", "Q", "Q", "S", "S", "D"]
                        CheckBox {
                            required property int index
                            required property string modelData
                            text: modelData
                            checked: (root.weekdayMask & (1 << index)) !== 0
                            padding: 2
                            onToggled: {
                                if (checked)
                                    root.weekdayMask |= 1 << index;
                                else
                                    root.weekdayMask &= ~(1 << index);
                            }
                        }
                    }
                }

                Label {
                    text: "Termina"
                }
                ComboBox {
                    id: customEnding
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Nunca", value: "never" },
                        { text: "Em uma data", value: "onDate" },
                        { text: "Após ocorrências", value: "afterCount" }
                    ]
                }

                Label {
                    visible: customEnding.currentValue === "onDate"
                    text: "Data final"
                }
                TextField {
                    id: customUntilDate
                    visible: customEnding.currentValue === "onDate"
                    Layout.fillWidth: true
                    placeholderText: "AAAA-MM-DD"
                }

                Label {
                    visible: customEnding.currentValue === "afterCount"
                    text: "Ocorrências"
                }
                SpinBox {
                    id: customOccurrenceCount
                    visible: customEnding.currentValue === "afterCount"
                    from: 1
                    to: 999
                    value: 10
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }
                Button {
                    text: "Cancelar"
                    flat: true
                    onClicked: editPopup.close()
                }
                Button {
                    text: "Salvar"
                    enabled: editTitle.text.trim() !== "" && editTime.acceptableInput
                    onClicked: root.saveEdit()
                }
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }
}
