pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data/TaskCategoryOptions.js" as TaskCategoryOptions

Rectangle {
    id: root

    required property var controller
    required property string scheduledDateKey
    property bool contextualDate: true
    property string placeholderText: "Nova tarefa…"
    property string draftTitle: ""
    property bool draftStarted: false
    property int step: 0
    property bool moreOptions: false
    property bool submitting: false
    property string saveError: ""
    property int weekdayMask: 0
    property string selectedEmoji: ""
    readonly property string optionsSummary: {
        const parts = [];
        if (selectedEmoji !== "")
            parts.push(selectedEmoji);
        parts.push(categoryInput.currentText || "Sem lista");
        if (preset.currentIndex === 5) {
            const units = { daily: "dia(s)", weekly: "semana(s)", monthly: "mês(es)", yearly: "ano(s)" };
            parts.push("A cada " + interval.value + " " + units[selectedFrequency()]);
            if (selectedFrequency() === "weekly") {
                const days = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"];
                parts.push(selectedWeekdays().map(day => days[day - 1]).join(", "));
            }
            if (ending.currentValue === "onDate")
                parts.push("Até " + untilDate.displayText);
            else if (ending.currentValue === "afterCount")
                parts.push(occurrenceCount.value + " ocorrências");
        } else if (selectedFrequency() !== "none") {
            parts.push(preset.currentText);
        }
        parts.push(reminderInput.minutesBefore.length === 0 ? "Sem lembretes"
            : reminderInput.minutesBefore.map(value => reminderInput.reminderLabel(value)).join(", "));
        return parts.join(" · ");
    }

    implicitHeight: 44
    radius: WaypointTheme.radius
    color: input.activeFocus ? WaypointTheme.controlHoverFill : WaypointTheme.controlFill
    border.width: 1
    border.color: input.activeFocus ? WaypointTheme.activeBorder : WaypointTheme.controlBorder

    function focusInput() {
        input.forceActiveFocus();
    }

    function categoryIndex(categoryId) {
        const options = TaskCategoryOptions.fromCategories(root.controller.taskCategories);
        for (let index = 0; index < options.length; ++index) {
            if (String(options[index].id) === categoryId)
                return index;
        }
        return 0;
    }

    function ensureDraft() {
        if (draftStarted)
            return;
        dateInput.dateKey = scheduledDateKey || Qt.formatDate(new Date(), "yyyy-MM-dd");
        timeInput.text = Qt.formatTime(new Date(), "HH:mm");
        untilDate.dateKey = dateInput.dateKey;
        draftStarted = true;
    }

    function selectList(categoryId) {
        ensureDraft();
        categoryInput.currentIndex = categoryIndex(categoryId);
        step = 0;
        creationPopup.open();
        Qt.callLater(() => titleInput.forceActiveFocus());
    }

    function anchorWeekdayIndex() {
        const parts = dateInput.dateKey.split("-");
        const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return (date.getDay() + 6) % 7;
    }

    function selectedFrequency() {
        if (preset.currentIndex === 1) return "daily";
        if (preset.currentIndex === 2) return "weekly";
        if (preset.currentIndex === 3) return "monthly";
        if (preset.currentIndex === 4) return "yearly";
        if (preset.currentIndex === 5) return customFrequency.currentValue;
        return "none";
    }

    function selectedWeekdays() {
        if (selectedFrequency() !== "weekly" || preset.currentIndex !== 5)
            return [];
        const selected = [];
        for (let index = 0; index < 7; ++index) {
            if ((weekdayMask & (1 << index)) !== 0)
                selected.push(index + 1);
        }
        return selected;
    }

    function focusStep() {
        Qt.callLater(() => {
            if (step === 0) titleInput.forceActiveFocus();
            else if (step === 1) dateInput.focusInput();
            else timeInput.forceActiveFocus();
        });
    }

    function beginSubmit() {
        if (draftTitle.trim() === "")
            return;
        ensureDraft();
        if (step === 0)
            step = contextualDate ? 2 : 1;
        creationPopup.open();
        focusStep();
    }

    function advance() {
        if (draftTitle.trim() === "")
            return;
        if (step === 0) step = contextualDate ? 2 : 1;
        else if (step === 1 && dateInput.acceptableInput) step = 2;
        focusStep();
    }

    function submit() {
        if (submitting || !draftStarted || !creationPopup.opened || step !== 2
                || draftTitle.trim() === "" || !dateInput.acceptableInput || !timeInput.acceptableInput)
            return;
        submitting = true;
        saveError = "";
        const custom = preset.currentIndex === 5;
        const endMode = custom ? ending.currentValue : "never";
        const saved = root.controller.addTask(draftTitle.trim(), dateInput.dateKey,
            timeInput.text, selectedFrequency(), custom ? interval.value : 1,
            selectedWeekdays(), endMode, endMode === "onDate" ? untilDate.dateKey : "",
            endMode === "afterCount" ? occurrenceCount.value : 0,
            reminderInput.minutesBefore, selectedEmoji, categoryInput.currentValue);
        submitting = false;
        if (!saved) {
            saveError = "Não foi possível criar a tarefa. Confira os dados e tente novamente.";
            return;
        }
        creationPopup.close();
        draftTitle = "";
        draftStarted = false;
        step = 0;
        selectedEmoji = "";
        moreOptions = false;
        preset.currentIndex = 0;
        interval.value = 1;
        ending.currentIndex = 0;
        weekdayMask = 0;
        reminderInput.setMinutesBefore([0]);
        categoryInput.currentIndex = 0;
    }

    TaskListManager {
        id: listManager
        controller: root.controller
        selectedListId: categoryInput.currentValue || ""
        onListSelected: listId => categoryInput.currentIndex = root.categoryIndex(listId)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        spacing: 8
        Text {
            text: "+"
            color: WaypointTheme.accent
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.headingSize
        }
        TextField {
            id: input
            Layout.fillWidth: true
            text: root.draftTitle
            placeholderText: root.placeholderText
            color: WaypointTheme.foreground
            placeholderTextColor: WaypointTheme.disabledText
            selectionColor: WaypointTheme.accent
            selectedTextColor: WaypointTheme.background
            background: Item {}
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySize
            onTextEdited: root.draftTitle = text
            onAccepted: root.beginSubmit()
        }
        AppButton {
            text: "Continuar"
            enabled: root.draftTitle.trim() !== ""
            onClicked: root.beginSubmit()
        }
    }

    Popup {
        id: creationPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(500, parent.width - 24)
        height: Math.min(form.implicitHeight + footer.implicitHeight + WaypointTheme.controlGap + padding * 2,
                         parent.height - 24)
        padding: WaypointTheme.popupPadding
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: WaypointTheme.scrim }
        background: Rectangle {
            radius: WaypointTheme.radius
            color: WaypointTheme.background
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap
            ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            id: formScroll
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                id: form
                width: formScroll.availableWidth
                spacing: WaypointTheme.controlGap
                Text {
                    text: root.step === 0 ? "NOVA TAREFA" : root.step === 1 ? "ESCOLHER DATA" : "ESCOLHER HORÁRIO"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.titleSize
                    font.bold: true
                }
                AppTextField {
                    id: titleInput
                    Layout.fillWidth: true
                    text: root.draftTitle
                    placeholderText: "Título da tarefa"
                    onTextEdited: root.draftTitle = text
                    onAccepted: root.advance()
                }
                RowLayout {
                    Layout.fillWidth: true
                    AppButton {
                        text: dateInput.acceptableInput ? dateInput.displayText : "Escolher data"
                        selected: root.step === 1
                        onClicked: { root.step = 1; root.focusStep(); }
                    }
                    AppButton {
                        text: timeInput.text
                        visible: root.step === 2
                        selected: true
                        onClicked: timeInput.forceActiveFocus()
                    }
                    Item { Layout.fillWidth: true }
                }
                AppDatePicker {
                    id: dateInput
                    Layout.fillWidth: true
                    visible: root.step === 1
                    embedded: true
                    onSelectionAccepted: root.advance()
                }
                AppTimePicker {
                    id: timeInput
                    Layout.fillWidth: true
                    visible: root.step === 2
                    embedded: true
                    onSelectionAccepted: root.submit()
                }
                Text {
                    Layout.fillWidth: true
                    text: root.optionsSummary
                    wrapMode: Text.WordWrap
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppButton {
                    text: root.moreOptions ? "Menos opções" : "Mais opções"
                    onClicked: root.moreOptions = !root.moreOptions
                }
                ColumnLayout {
                    visible: root.moreOptions
                    Layout.fillWidth: true
                    spacing: WaypointTheme.controlGap
                    RowLayout {
                        Layout.fillWidth: true
                        AppEmojiPicker {
                            emoji: root.selectedEmoji
                            onSelectionAccepted: selectedEmoji => root.selectedEmoji = selectedEmoji
                        }
                        AppComboBox {
                            id: categoryInput
                            Layout.fillWidth: true
                            textRole: "name"
                            valueRole: "id"
                            colorRole: "color"
                            model: TaskCategoryOptions.fromCategories(root.controller.taskCategories)
                            Accessible.name: "Lista da tarefa"
                        }
                        AppButton {
                            text: "…"
                            Accessible.name: "Gerenciar listas"
                            onClicked: listManager.openManager()
                        }
                    }
                    AppReminderPicker {
                        id: reminderInput
                        Layout.fillWidth: true
                    }
                    AppComboBox {
                        id: preset
                        Layout.fillWidth: true
                        Accessible.name: "Repetição"
                        model: ["Não repetir", "Diariamente", "Semanalmente", "Mensalmente", "Anualmente", "Personalizado"]
                    }
                    GridLayout {
                        visible: preset.currentIndex === 5
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 8
                        Label { text: "Frequência"; color: WaypointTheme.subduedText }
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
                        Label { text: "A cada"; color: WaypointTheme.subduedText }
                        AppSpinBox { id: interval; from: 1; to: 99; value: 1 }
                        Label {
                            visible: customFrequency.currentValue === "weekly"
                            text: "Dias"
                            color: WaypointTheme.subduedText
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
                        Label { text: "Termina"; color: WaypointTheme.subduedText }
                        AppComboBox {
                            id: ending
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
                            visible: ending.currentValue === "onDate"
                            text: "Data final"
                            color: WaypointTheme.subduedText
                        }
                        AppDatePicker {
                            id: untilDate
                            visible: ending.currentValue === "onDate"
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: ending.currentValue === "afterCount"
                            text: "Ocorrências"
                            color: WaypointTheme.subduedText
                        }
                        AppSpinBox {
                            id: occurrenceCount
                            visible: ending.currentValue === "afterCount"
                            from: 1
                            to: 999
                            value: 10
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.saveError !== ""
                    text: root.saveError
                    wrapMode: Text.WordWrap
                    color: WaypointTheme.urgent
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
            }
            }
                RowLayout {
                    id: footer
                    Layout.fillWidth: true
                    AppButton {
                        text: "Voltar"
                        visible: root.step > 0
                        onClicked: {
                            root.step = root.step === 2 && !root.contextualDate ? 1 : 0;
                            root.focusStep();
                        }
                    }
                    Item { Layout.fillWidth: true }
                    AppButton {
                        text: "Cancelar"
                        onClicked: creationPopup.close()
                    }
                    AppButton {
                        text: root.step === 2 ? "Criar" : "Continuar"
                        selected: true
                        enabled: !root.submitting && root.draftTitle.trim() !== ""
                            && (root.step === 0 || dateInput.acceptableInput)
                            && (root.step !== 2 || timeInput.acceptableInput)
                        onClicked: root.step === 2 ? root.submit() : root.advance()
                    }
                }
        }
    }
}
