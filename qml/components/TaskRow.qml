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
    required property string emoji
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
    radius: WaypointTheme.radius
    color: pointer.containsMouse ? WaypointTheme.controlHoverFill : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: WaypointTheme.radius
            color: root.completed ? WaypointTheme.accent : WaypointTheme.controlFill
            border.width: 1
            border.color: root.completed ? WaypointTheme.accent
                        : root.overdue ? WaypointTheme.urgent
                        : WaypointTheme.controlBorder

            Text {
                anchors.centerIn: parent
                visible: root.completed
                text: "✓"
                color: WaypointTheme.background
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
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

        Text {
            Layout.preferredWidth: 26
            Layout.alignment: Qt.AlignVCenter
            text: root.emoji
            horizontalAlignment: Text.AlignHCenter
            color: root.completed ? WaypointTheme.disabledText : WaypointTheme.foreground
            font.family: "Noto Color Emoji"
            font.pixelSize: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.completed ? WaypointTheme.disabledText : WaypointTheme.foreground
                elide: Text.ElideRight
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
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
                color: root.overdue ? WaypointTheme.urgent : WaypointTheme.accent
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.bold: true
                font.letterSpacing: 1
            }
        }

        Text {
            text: root.scheduledTimeKey
            color: root.completed ? WaypointTheme.disabledText : WaypointTheme.subduedText
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySmallSize
        }

        AppButton {
            id: taskActions
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            square: true
            text: "⋯"
            onClicked: root.openActionsMenuFromButton()
            ToolTip.visible: hovered
            ToolTip.text: "Editar ou excluir tarefa"

            Menu {
                id: actionsMenu
                y: taskActions.height + 4
                width: 236
                padding: 4

                background: Rectangle {
                    radius: WaypointTheme.radius
                    color: WaypointTheme.background
                    border.width: 1
                    border.color: WaypointTheme.activeBorder
                }

                AppMenuItem {
                    text: "Editar"
                    onTriggered: root.openEditor()
                }
                MenuSeparator {
                    contentItem: Rectangle {
                        implicitHeight: 1
                        color: WaypointTheme.divider
                    }
                }
                AppMenuItem {
                    visible: !root.recurring
                    destructive: true
                    text: "Excluir tarefa"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "series")
                }
                AppMenuItem {
                    visible: root.recurring
                    destructive: true
                    text: "Excluir esta ocorrência"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "occurrence")
                }
                AppMenuItem {
                    visible: root.recurring
                    destructive: true
                    text: "Excluir esta e as seguintes"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "following")
                }
                AppMenuItem {
                    visible: root.recurring
                    destructive: true
                    text: "Excluir toda a série"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "series")
                }
            }
        }
    }

    function openActionsMenuFromButton() {
        actionsMenu.x = 0;
        actionsMenu.y = taskActions.height + 4;
        actionsMenu.open();
    }

    function openActionsMenuAt(rowPosition) {
        const popupPosition = root.mapToItem(taskActions, rowPosition.x, rowPosition.y);
        actionsMenu.x = popupPosition.x;
        actionsMenu.y = popupPosition.y;
        actionsMenu.open();
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: eventPoint => root.openActionsMenuAt(eventPoint.position)
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
        editEmoji.emoji = root.emoji;
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
                endMode === "afterCount" ? customOccurrenceCount.value : 0,
                editEmoji.emoji))
            editPopup.close();
    }

    Popup {
        id: editPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(420, parent.width - 24)
        padding: WaypointTheme.popupPadding
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle {
            color: WaypointTheme.scrim
        }

        background: Rectangle {
            radius: WaypointTheme.radius
            color: WaypointTheme.background
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap

            Text {
                text: "EDITAR TAREFA"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.titleSize
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: WaypointTheme.controlGap

                AppEmojiPicker {
                    id: editEmoji
                }
                AppTextField {
                    id: editTitle
                    Layout.fillWidth: true
                    placeholderText: "Título"
                    onAccepted: editTime.forceActiveFocus()
                }
            }

            AppTimePicker {
                id: editTime
                Layout.fillWidth: true
            }

            AppComboBox {
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
                rowSpacing: 8

                Text {
                    text: "Frequência"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppComboBox {
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

                Text {
                    text: "A cada"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                RowLayout {
                    AppSpinBox {
                        id: customInterval
                        from: 1
                        to: 99
                        value: 1
                    }
                    Text {
                        text: customFrequency.currentValue === "daily" ? "dia(s)"
                            : customFrequency.currentValue === "weekly" ? "semana(s)"
                            : customFrequency.currentValue === "monthly" ? "mês(es)" : "ano(s)"
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }
                }

                Text {
                    text: "Somente em"
                    visible: customFrequency.currentValue === "weekly"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                RowLayout {
                    visible: customFrequency.currentValue === "weekly"
                    spacing: 4
                    Repeater {
                        model: ["S", "T", "Q", "Q", "S", "S", "D"]
                        AppButton {
                            required property int index
                            required property string modelData
                            Layout.preferredWidth: 32
                            square: true
                            selected: (root.weekdayMask & (1 << index)) !== 0
                            text: modelData
                            onClicked: root.weekdayMask ^= 1 << index
                        }
                    }
                }

                Text {
                    text: "Termina"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppComboBox {
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

                Text {
                    visible: customEnding.currentValue === "onDate"
                    text: "Data final"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppTextField {
                    id: customUntilDate
                    visible: customEnding.currentValue === "onDate"
                    Layout.fillWidth: true
                    placeholderText: "AAAA-MM-DD"
                }

                Text {
                    visible: customEnding.currentValue === "afterCount"
                    text: "Ocorrências"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppSpinBox {
                    id: customOccurrenceCount
                    visible: customEnding.currentValue === "afterCount"
                    from: 1
                    to: 999
                    value: 10
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Item {
                    Layout.fillWidth: true
                }
                AppButton {
                    text: "Cancelar"
                    onClicked: editPopup.close()
                }
                AppButton {
                    text: "Salvar"
                    selected: true
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
