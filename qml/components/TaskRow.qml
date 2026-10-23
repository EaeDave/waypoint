pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data/TaskCategoryOptions.js" as TaskCategoryOptions
import "../data/Labels.js" as Labels

Rectangle {
    id: root

    required property string taskId
    required property string title
    required property string scheduledDateKey
    required property string scheduledTimeKey
    required property string emoji
    required property string categoryId
    required property string categoryName
    required property string categoryColor
    required property bool completed
    required property string completedDate
    required property string registeredAt
    required property string completionLabel
    required property bool completionLate
    required property bool skipped
    required property bool overdue
    required property bool recurring
    required property string recurrenceLabel
    required property var recurrence
    required property var reminderMinutesBefore
    required property var controller
    required property var completionActions
    property int weekdayMask: 0
    property bool definitionMode: false
    property string pendingDate: ""
    property bool showDivider: false
    readonly property var portugueseLocale: Qt.locale("pt_BR")
    readonly property date scheduledDateValue: {
        const parts = scheduledDateKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    // The checkbox carries the list colour; overdue and skipped states override it.
    readonly property color statusColor: root.overdue || root.skipped ? WaypointTheme.urgent
                                       : root.categoryName !== "" ? root.categoryColor
                                       : WaypointTheme.accent

    implicitHeight: Math.max(52, rowContent.implicitHeight + 16)
    color: "transparent"

    Rectangle {
        visible: root.showDivider
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: WaypointTheme.divider
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: WaypointTheme.radius
        color: WaypointTheme.controlFill
        visible: pointer.hovered || actionsMenu.opened
    }

    RowLayout {
        id: rowContent
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 12

        Rectangle {
            visible: !root.definitionMode
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: 5
            opacity: root.completed ? 0.6 : 1
            color: root.completed || root.skipped ? root.statusColor
                 : checkHover.hovered ? Qt.rgba(root.statusColor.r, root.statusColor.g,
                                                root.statusColor.b, 0.18)
                 : "transparent"
            border.width: 1.5
            border.color: root.statusColor

            AppIcon {
                anchors.centerIn: parent
                width: 12
                height: 12
                visible: root.completed || root.skipped
                name: root.completed ? "check" : "close"
                color: WaypointTheme.background
                strokeWidth: 2
            }

            HoverHandler {
                id: checkHover
                cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.CheckBox
                Accessible.name: (root.completed ? "Reabrir " : "Concluir ") + root.title
                onClicked: root.completionActions.toggle(root.taskId, root.scheduledDateKey,
                    root.completed, root.skipped, root.overdue)
            }
        }

        Text {
            visible: root.emoji !== ""
            Layout.preferredWidth: 22
            Layout.alignment: Qt.AlignVCenter
            text: root.emoji
            horizontalAlignment: Text.AlignHCenter
            opacity: root.completed ? 0.45 : 1
            font.family: "Noto Color Emoji"
            font.pixelSize: 17
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.completed ? WaypointTheme.disabledText
                     : root.skipped ? WaypointTheme.urgent : WaypointTheme.foreground
                elide: Text.ElideRight
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
                font.strikeout: root.completed
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.WordWrap
                text: {
                    const parts = [];
                    if (root.categoryName !== "")
                        parts.push(root.categoryName);
                    if (root.completed)
                        parts.push(Labels.sentenceCase(root.completionLabel));
                    if (root.definitionMode) {
                        parts.push(root.recurring ? Labels.sentenceCase(root.recurrenceLabel) : "Única");
                        if (root.overdue)
                            parts.push("Atrasada");
                        else if (root.recurring && root.pendingDate === "")
                            parts.push("Sem pendências");
                    } else if (root.skipped) {
                        parts.push("Não feita · " + root.portugueseLocale.toString(
                            root.scheduledDateValue, "d MMM"));
                    } else if (root.overdue) {
                        parts.push("Atrasada · " + root.portugueseLocale.toString(
                            root.scheduledDateValue, "d MMM"));
                    }
                    if (!root.definitionMode && root.recurring)
                        parts.push(Labels.sentenceCase(root.recurrenceLabel));
                    return parts.join(" · ");
                }
                color: root.completed
                     ? (root.completionLate ? WaypointTheme.warning : WaypointTheme.disabledText)
                     : root.skipped || root.overdue ? WaypointTheme.urgent
                     : WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
            }
        }

        RowLayout {
            id: schedule
            spacing: 6
            readonly property int reminderCount: (root.reminderMinutesBefore || []).length
            readonly property color tint: root.completed ? WaypointTheme.disabledText
                                        : root.skipped || root.overdue ? WaypointTheme.urgent
                                        : WaypointTheme.subduedText

            Text {
                text: {
                    const parts = [];
                    if (root.definitionMode) {
                        const dateKey = root.recurring ? root.pendingDate : root.scheduledDateKey;
                        if (dateKey !== "")
                            parts.push(root.portugueseLocale.toString(
                                new Date(dateKey + "T00:00:00"), "d MMM"));
                    }
                    parts.push(root.scheduledTimeKey);
                    return parts.join(" · ");
                }
                color: schedule.tint
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
                font.features: WaypointTheme.tabularNumbers
            }

            AppIcon {
                visible: schedule.reminderCount > 0
                Layout.preferredWidth: 13
                Layout.preferredHeight: 13
                Layout.leftMargin: 2
                name: "bell"
                color: schedule.tint
                strokeWidth: 1.4
            }

            Text {
                visible: schedule.reminderCount > 0
                text: schedule.reminderCount
                color: schedule.tint
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.features: WaypointTheme.tabularNumbers
            }
        }

        AppButton {
            id: taskActions
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            square: true
            flat: true
            opacity: pointer.hovered || activeFocus || actionsMenu.opened ? 1 : 0
            onClicked: root.openActionsMenuFromButton()
            Accessible.name: root.definitionMode ? "Editar ou excluir tarefa"
                                                 : "Editar, marcar status ou excluir tarefa"
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name
            contentItem: Item {
                AppIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    name: "more"
                    color: WaypointTheme.subduedText
                }
            }
            Menu {
                id: actionsMenu
                y: taskActions.height + 4
                width: 236
                padding: 4

                background: Rectangle {
                    radius: WaypointTheme.radius
                    color: WaypointTheme.popupFill
                    border.width: 1
                    border.color: WaypointTheme.controlBorder
                }

                AppMenuItem {
                    text: "Editar"
                    onTriggered: root.openEditor()
                }
                AppMenuItem {
                    visible: (!root.definitionMode || !root.recurring) && !root.completed && !root.skipped
                    text: "Concluir"
                    onTriggered: root.completionActions.toggle(root.taskId, root.scheduledDateKey,
                        false, false, root.overdue)
                }
                AppMenuItem {
                    visible: root.completed
                    text: "Alterar data da conclusão"
                    onTriggered: root.completionActions.choose(root.taskId, root.scheduledDateKey,
                        root.completedDate, true)
                }
                AppMenuItem {
                    visible: root.completed
                    text: "Desfazer conclusão"
                    onTriggered: root.completionActions.commit(root.taskId, root.scheduledDateKey, false, "")
                }
                MenuSeparator {
                    contentItem: Rectangle {
                        implicitHeight: 1
                        color: WaypointTheme.divider
                    }
                }
                AppMenuItem {
                    visible: root.definitionMode || !root.recurring
                    destructive: true
                    text: "Excluir tarefa"
                    onTriggered: {
                        if (root.definitionMode)
                            root.controller.deleteTask(root.taskId);
                        else
                            root.controller.deleteOccurrence(root.taskId,
                                                             root.scheduledDateKey,
                                                             "series");
                    }
                }
                AppMenuItem {
                    visible: !root.definitionMode && root.recurring
                             && !root.completed && !root.skipped
                    text: "Marcar como não feita"
                    onTriggered: root.controller.skipOccurrence(root.taskId,
                                                                root.scheduledDateKey)
                }
                AppMenuItem {
                    visible: !root.definitionMode && root.skipped
                    text: "Reabrir ocorrência"
                    onTriggered: root.completionActions.commit(root.taskId, root.scheduledDateKey, false, "")
                }
                AppMenuItem {
                    visible: !root.definitionMode && root.recurring
                    destructive: true
                    text: "Excluir esta e as seguintes"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "following")
                }
                AppMenuItem {
                    visible: !root.definitionMode && root.recurring
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

    function categoryIndex(categoryId) {
        const options = TaskCategoryOptions.fromCategories(root.controller.taskCategories);
        for (let index = 0; index < options.length; ++index) {
            if (String(options[index].id) === categoryId)
                return index;
        }
        return 0;
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
        editDate.dateKey = root.scheduledDateKey;
        editTime.text = root.scheduledTimeKey;
        editEmoji.emoji = root.emoji;
        editReminders.setMinutesBefore(root.reminderMinutesBefore || [0]);
        editCategory.currentIndex = root.categoryIndex(root.categoryId);
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
        customUntilDate.dateKey = String(root.recurrence.untilDate || root.scheduledDateKey);
        customOccurrenceCount.value = Math.max(1, Number(root.recurrence.occurrenceCount || 10));
        recurrenceInput.currentIndex = root.recurrencePresetIndex();
        editPopup.open();
        editTitle.forceActiveFocus();
        editTitle.selectAll();
    }

    function saveEdit() {
        const normalizedTitle = editTitle.text.trim();
        const normalizedTime = editTime.text.trim();
        if (normalizedTitle === "" || !editDate.acceptableInput || !editTime.acceptableInput)
            return;

        const custom = recurrenceInput.currentIndex === 5;
        const frequency = root.selectedFrequency();
        const endMode = custom ? customEnding.currentValue : "never";
        if (root.controller.editTask(
                root.taskId, editDate.dateKey, normalizedTitle, normalizedTime,
                frequency, custom ? customInterval.value : 1, root.selectedWeekdays(),
                endMode, endMode === "onDate" ? customUntilDate.dateKey : "",
                endMode === "afterCount" ? customOccurrenceCount.value : 0,
                editReminders.minutesBefore, editEmoji.emoji,
                editCategory.currentValue))
            editPopup.close();
    }

    TaskListManager {
        id: listManager
        controller: root.controller
        selectedListId: editCategory.currentValue || ""
        onListSelected: function(listId) {
            editCategory.currentIndex = root.categoryIndex(listId);
        }
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
            radius: WaypointTheme.radiusLarge
            color: WaypointTheme.popupFill
            border.width: 1
            border.color: WaypointTheme.controlBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap

            Text {
                Layout.bottomMargin: 4
                text: "Editar tarefa"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.headingSize
                font.weight: WaypointTheme.weightSemiBold
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

            AppDatePicker {
                id: editDate
                Layout.fillWidth: true
            }

            AppTimePicker {
                id: editTime
                Layout.fillWidth: true
            }

            AppReminderPicker {
                id: editReminders
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppComboBox {
                    id: editCategory
                    Layout.fillWidth: true
                    textRole: "name"
                    valueRole: "id"
                    colorRole: "color"
                    model: TaskCategoryOptions.fromCategories(root.controller.taskCategories)
                }

                AppButton {
                    text: "Listas…"
                    onClicked: listManager.openManager()
                }
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
                AppDatePicker {
                    id: customUntilDate
                    visible: customEnding.currentValue === "onDate"
                    Layout.fillWidth: true
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
                    flat: true
                    onClicked: editPopup.close()
                }
                AppButton {
                    text: "Salvar"
                    highlighted: true
                    enabled: editTitle.text.trim() !== "" && editDate.acceptableInput
                             && editTime.acceptableInput
                    onClicked: root.saveEdit()
                }
            }
        }
    }

    HoverHandler {
        id: pointer
    }
}
