pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../data/TaskCategoryOptions.js" as TaskCategoryOptions

Popup {
    id: root

    required property var controller
    property var editingTask: ({})
    property bool editingDefinition: false
    property var selectedWeekdays: []
    property var selectedReminders: [0]
    property string scheduledDate: ""
    property string scheduledTime: ""
    property string untilDate: ""
    property string picker: ""
    property int step: 0
    property bool contextualDate: false
    property bool moreOptions: false
    property bool saving: false
    property bool committed: false
    property string validationMessage: ""
    property var creationDraft: null
    property string createContext: ""
    readonly property var portugueseLocale: Qt.locale("pt_BR")
    readonly property bool auxiliaryPicker: picker === "until" || (step === 3 && picker !== "") || (step === 2 && picker === "date")
    readonly property string actionLabel: auxiliaryPicker ? "OK" : step < 2 ? "PRÓXIMO" : editingTask.taskId ? "SALVAR" : "CRIAR"
    readonly property real safeTop: parent ? parent.SafeArea.margins.top : 0
    readonly property real safeHeight: parent ? Math.max(0, parent.height - safeTop - parent.SafeArea.margins.bottom) : 0

    parent: Overlay.overlay
    x: parent ? (parent.width - width) / 2 : 0
    y: safeTop + (safeHeight - height) / 2
    width: parent ? Math.min(parent.width, 560) : 0
    height: Math.min(safeHeight, step === 0 && !moreOptions && picker === "" ? 440 : 760)
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose
    padding: 0
    onClosed: {
        if (!committed && !editingTask.taskId)
            creationDraft = snapshot();
    }

    function snapshot() {
        return {
            context: createContext,
            title: titleField.text, emoji: emojiField.text, date: scheduledDate, time: scheduledTime,
            frequency: frequencyField.currentIndex, interval: intervalField.value,
            weekdays: selectedWeekdays.slice(), end: endField.currentIndex, until: untilDate,
            count: countField.value, reminders: selectedReminders.slice(),
            listId: categoryField.currentValue || "", step: step, contextual: contextualDate
        };
    }

    function restoreDraft() {
        const draft = creationDraft;
        if (editingTask.taskId || !draft || draft.context !== createContext)
            return;
        titleField.text = draft.title;
        emojiField.text = draft.emoji;
        scheduledDate = draft.date;
        scheduledTime = draft.time;
        frequencyField.currentIndex = draft.frequency;
        intervalField.value = draft.interval;
        selectedWeekdays = draft.weekdays;
        endField.currentIndex = draft.end;
        untilDate = draft.until;
        countField.value = draft.count;
        selectedReminders = draft.reminders;
        categoryField.currentIndex = categoryIndex(draft.listId);
        step = draft.step;
        contextualDate = draft.contextual;
    }

    function displayDate(dateKey) {
        if (!dateKey)
            return "Escolher data";
        const parts = dateKey.split("-");
        return portugueseLocale.toString(new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])), "dd/MM/yyyy");
    }

    function showPicker(value) {
        picker = value;
        Qt.inputMethod.hide();
        if (value === "date" || value === "until")
            datePicker.show(value === "until" ? untilDate : scheduledDate);
        if (value === "time") {
            const parts = scheduledTime.split(":");
            hourField.currentIndex = Number(parts[0]);
            minuteField.currentIndex = Number(parts[1]);
        }
        primaryAction.forceActiveFocus();
        Qt.callLater(() => {
            if (value !== "")
                editorScroll.contentItem.contentY = Math.max(0, (value === "time" ? timePicker.y : datePicker.y) - 12);
            else
                editorScroll.contentItem.contentY = 0;
        });
    }

    function advance() {
        if (saving || committed || !titleField.text.trim())
            return;
        if (auxiliaryPicker) {
            showPicker(step === 1 ? "date" : step === 2 ? "time" : "");
            return;
        }
        if (step === 0)
            step = contextualDate ? 2 : 1;
        else if (step === 1)
            step = 2;
        else {
            save();
            return;
        }
        showPicker(step === 1 ? "date" : step === 2 ? "time" : "");
    }

    function back() {
        if (auxiliaryPicker) {
            showPicker(step === 1 ? "date" : step === 2 ? "time" : "");
        } else if (!editingTask.taskId && step > 0) {
            step = step === 2 && contextualDate ? 0 : step - 1;
            showPicker(step === 1 ? "date" : step === 2 ? "time" : "");
        } else {
            close();
        }
    }

    function present() {
        committed = false;
        saving = false;
        validationMessage = "";
        moreOptions = false;
        picker = "";
        restoreDraft();
        open();
        if (step === 1 || step === 2)
            showPicker(step === 1 ? "date" : "time");
        else
            titleField.forceActiveFocus();
    }

    function frequencyIndex(value) {
        const values = ["none", "daily", "weekly", "monthly", "yearly"];
        return Math.max(0, values.indexOf(value));
    }

    function endIndex(value) {
        const values = ["never", "onDate", "afterCount"];
        return Math.max(0, values.indexOf(value));
    }

    function categoryIndex(categoryId) {
        if (!categoryId)
            return 0;
        for (let index = 1; index < categoryField.count; ++index) {
            if (categoryField.valueAt(index) === categoryId)
                return index;
        }
        return 0;
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

    function openForCreate(dateKey, listId) {
        createContext = "create:" + (listId || "") + ":" + (dateKey || "");
        editingTask = ({});
        editingDefinition = false;
        emojiField.text = "";
        titleField.text = "";
        scheduledDate = dateKey || controller.todayKey;
        scheduledTime = Qt.formatTime(new Date(), "HH:mm");
        contextualDate = !!dateKey;
        step = 0;
        frequencyField.currentIndex = 0;
        intervalField.value = 1;
        selectedWeekdays = [];
        endField.currentIndex = 0;
        untilDate = scheduledDate;
        countField.value = 10;
        selectedReminders = [0];
        categoryField.currentIndex = categoryIndex(listId || "");
        present();
    }

    function openForEdit(task) {
        editingTask = task;
        editingDefinition = !task.occurrenceDate;
        const recurrence = task.recurrence || {};
        emojiField.text = task.emoji || "";
        titleField.text = task.title || "";
        scheduledDate = task.scheduledDate || task.occurrenceDate || "";
        scheduledTime = task.scheduledTime || Qt.formatTime(new Date(), "HH:mm");
        contextualDate = true;
        step = 3;
        frequencyField.currentIndex = frequencyIndex(recurrence.frequency || "none");
        intervalField.value = recurrence.interval || 1;
        selectedWeekdays = recurrence.weekdays || [];
        endField.currentIndex = endIndex(recurrence.endMode || "never");
        untilDate = recurrence.untilDate || scheduledDate || controller.todayKey;
        countField.value = recurrence.occurrenceCount || 10;
        selectedReminders = task.reminderMinutesBefore || [];
        categoryField.currentIndex = categoryIndex(task.categoryId || "");
        present();
    }

    function save() {
        if (saving || committed || step < 2 || !titleField.text.trim())
            return;
        saving = true;
        validationMessage = "";
        const frequencies = ["none", "daily", "weekly", "monthly", "yearly"];
        const ends = ["never", "onDate", "afterCount"];
        const succeeded = controller.saveTask(editingTask.taskId || "", titleField.text, scheduledDate, scheduledTime, frequencies[frequencyField.currentIndex], intervalField.value, selectedWeekdays, ends[endField.currentIndex], untilDate, countField.value, selectedReminders, emojiField.text, categoryField.currentValue || "");
        saving = false;
        if (succeeded) {
            committed = true;
            if (!editingTask.taskId)
                creationDraft = null;
            close();
        } else {
            validationMessage = controller.errorMessage || "Não foi possível salvar. Seu rascunho foi mantido.";
        }
    }

    CompletionActions {
        id: completionFlow
        controller: root.controller
        onCommitted: root.close()
    }


    Overlay.modal: Rectangle {
        color: MobileTheme.scrim
    }

    background: Rectangle {
        color: MobileTheme.background
        radius: root.width < (root.parent ? root.parent.width : 0) ? MobileTheme.radius : 0
    }

    contentItem: ColumnLayout {
        spacing: 0
        Keys.onEscapePressed: root.back()
        Keys.onBackPressed: root.back()

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
                    Accessible.name: "Voltar sem perder o rascunho"
                    onClicked: root.back()
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
                    id: primaryAction
                    Layout.preferredWidth: 108
                    text: root.actionLabel
                    accent: true
                    Accessible.id: "task-editor-save"
                    enabled: titleField.text.trim().length > 0 && !root.saving
                    onClicked: root.advance()
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
                        EnterKey.type: Qt.EnterKeyGo
                        onAccepted: root.advance()
                    }
                }

                Text {
                    text: "LISTA"
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
                        id: categoryField
                        Layout.fillWidth: true
                        model: TaskCategoryOptions.fromCategories(root.controller.taskCategories)
                        textRole: "name"
                        valueRole: "id"
                        colorRole: "color"
                        Accessible.id: "task-editor-category"
                        Accessible.name: "Lista da tarefa"
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

                    MobileButton {
                        Layout.fillWidth: true
                        text: root.displayDate(root.scheduledDate)
                        Accessible.name: "Data da tarefa"
                        Accessible.id: "task-editor-date"
                        onClicked: root.showPicker("date")
                    }

                    MobileButton {
                        Layout.preferredWidth: 100
                        text: root.scheduledTime
                        Accessible.name: "Hora da tarefa"
                        Accessible.id: "task-editor-time"
                        onClicked: root.showPicker("time")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.editingTask.taskId
                    text: root.step === 0 ? "Escreva o título e avance."
                          : root.step === 1 ? "Escolha a data e avance para o horário."
                          : "Escolha o horário. Toque em CRIAR para confirmar."
                    color: MobileTheme.subdued
                    font.pixelSize: MobileTheme.captionSize
                    wrapMode: Text.Wrap
                }

                MobileDatePicker {
                    id: datePicker
                    Layout.fillWidth: true
                    visible: root.picker === "date" || root.picker === "until"
                    onDateSelected: function(dateKey) {
                        if (root.picker === "until")
                            root.untilDate = dateKey;
                        else
                            root.scheduledDate = dateKey;
                    }
                }

                RowLayout {
                    id: timePicker
                    Layout.fillWidth: true
                    visible: root.picker === "time"
                    spacing: 8
                    Tumbler {
                        id: hourField
                        Layout.fillWidth: true
                        implicitHeight: 144
                        visibleItemCount: 3
                        model: 24
                        Accessible.name: "Horas"
                        onCurrentIndexChanged: {
                            if (root.picker === "time" && currentIndex >= 0)
                                root.scheduledTime = String(currentIndex).padStart(2, "0") + ":" + root.scheduledTime.split(":")[1];
                        }
                        delegate: Label {
                            required property int modelData
                            text: String(modelData).padStart(2, "0")
                            color: MobileTheme.foreground
                            opacity: 1 - Math.abs(Tumbler.displacement) / 3
                            font.pixelSize: 24
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Label {
                        text: ":"
                        color: MobileTheme.foreground
                        font.pixelSize: 24
                    }
                    Tumbler {
                        id: minuteField
                        Layout.fillWidth: true
                        implicitHeight: 144
                        visibleItemCount: 3
                        model: 60
                        Accessible.name: "Minutos"
                        onCurrentIndexChanged: {
                            if (root.picker === "time" && currentIndex >= 0)
                                root.scheduledTime = root.scheduledTime.split(":")[0] + ":" + String(currentIndex).padStart(2, "0");
                        }
                        delegate: Label {
                            required property int modelData
                            text: String(modelData).padStart(2, "0")
                            color: MobileTheme.foreground
                            opacity: 1 - Math.abs(Tumbler.displacement) / 3
                            font.pixelSize: 24
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                MobileButton {
                    Layout.fillWidth: true
                    text: root.moreOptions ? "MENOS OPÇÕES" : "MAIS OPÇÕES"
                    Accessible.id: "task-editor-more-options"
                    onClicked: root.moreOptions = !root.moreOptions
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        let summary = frequencyField.currentText;
                        if (frequencyField.currentIndex > 0) {
                            summary += " · intervalo " + intervalField.value;
                            if (frequencyField.currentIndex === 2 && root.selectedWeekdays.length)
                                summary += " · " + root.selectedWeekdays.map(day => ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"][day - 1]).join(", ");
                            if (endField.currentIndex === 1)
                                summary += " · até " + root.displayDate(root.untilDate);
                            else if (endField.currentIndex === 2)
                                summary += " · " + countField.value + " ocorrências";
                        }
                        return summary + " · " + (root.selectedReminders.length
                            ? root.selectedReminders.map(minutes => minutes === 0 ? "na hora" : minutes % 1440 === 0 ? minutes / 1440 + " dia(s) antes" : minutes % 60 === 0 ? minutes / 60 + " h antes" : minutes + " min antes").join(", ")
                            : "Sem lembrete");
                    }
                    color: MobileTheme.subdued
                    font.pixelSize: MobileTheme.captionSize
                    wrapMode: Text.Wrap
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.moreOptions
                    spacing: 12

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

                MobileButton {
                    Layout.fillWidth: true
                    visible: frequencyField.currentIndex > 0 && endField.currentIndex === 1
                    text: "Até " + root.displayDate(root.untilDate)
                    Accessible.name: "Última data da repetição"
                    onClicked: root.showPicker("until")
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
                                value: 5,
                                label: "5 min"
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
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.validationMessage !== ""
                    text: root.validationMessage
                    color: MobileTheme.urgent
                    font.pixelSize: MobileTheme.bodySize
                    wrapMode: Text.Wrap
                    Accessible.name: text
                }

                Text {
                    Layout.fillWidth: true
                    visible: !!root.editingTask.completed
                    text: root.editingTask.completionLabel || ""
                    color: root.editingTask.completionLate ? MobileTheme.warning : MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    wrapMode: Text.Wrap
                }

                MobileButton {
                    Layout.fillWidth: true
                    visible: !!root.editingTask.taskId && !!root.editingTask.completed
                    text: "ALTERAR DATA DA CONCLUSÃO"
                    onClicked: completionFlow.edit(root.editingTask)
                }

                MobileButton {
                    Layout.fillWidth: true
                    visible: !!root.editingTask.taskId
                             && (!root.editingDefinition || !root.editingTask.recurring)
                             && !root.editingTask.skipped
                    text: root.editingTask.completed ? "DESFAZER CONCLUSÃO" : "CONCLUIR TAREFA"
                    onClicked: completionFlow.toggle(root.editingTask)
                }

                MobileButton {
                    Layout.fillWidth: true
                    visible: !root.editingDefinition && !!root.editingTask.taskId
                             && root.editingTask.recurring && !root.editingTask.completed
                             && !root.editingTask.skipped
                    text: "MARCAR COMO NÃO FEITA"
                    onClicked: {
                        if (root.controller.skipTaskOccurrence(root.editingTask.taskId,
                                                               root.editingTask.occurrenceDate))
                            root.close();
                    }
                }

                MobileButton {
                    Layout.fillWidth: true
                    visible: !root.editingDefinition && !!root.editingTask.taskId
                             && root.editingTask.skipped
                    text: "REABRIR OCORRÊNCIA"
                    onClicked: completionFlow.toggle(root.editingTask)
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
