pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "io.waypoint.bar"
    ipcTarget: "io.waypoint.bar"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var occurrences: []
    property var categories: []
    property var todayTasks: []
    property var selectedHabits: []
    property var selectedRegistrationActivity: []
    property bool registrationActivityExpanded: false
    property var expandedActivityTasks: ({})
    property var completionTask: null
    property var editedTask: null
    property bool completionPickerVisible: false
    property bool completionCustomDateVisible: false
    property string completionFeedback: ""
    property var completionUndo: null
    readonly property color completionLateColor: "#d9a441"
    property var holidays: []
    property var holidaySyncStatus: ({ state: "local-only", lastError: "" })
    property string loadError: ""
    property string taskVisibility: "all"
    property var syncStatus: ({ state: "local-only", configured: false, lastError: "" })
    property var updateStatus: ({ state: "idle", currentVersion: "", latestVersion: "",
                                  canInstall: false, error: "" })
    property date today: new Date()
    property date selectedDate: new Date()
    property int viewYear: selectedDate.getFullYear()
    property int viewMonth: selectedDate.getMonth()
    property bool taskEditorVisible: false
    property string editingTaskId: ""
    property string editingOccurrenceDate: ""
    property bool editingCompleted: false
    property bool editingSkipped: false
    property bool timePickerVisible: false
    property bool reminderPickerVisible: false
    property var timePickerTarget: null
    property bool timePickerAddsHabitReminder: false
    property bool creatingTask: false
    property bool creationPending: false
    property bool taskMoreOptions: false
    property var quickDraft: null
    property date pendingQuickDate: new Date()
    property bool taskDatePickerVisible: false
    property date taskPickerMonth: new Date()
    property bool taskDatePickerForEnding: false
    property string editingEmoji: ""
    property string editingCategoryId: ""
    property string emojiPickerTarget: ""
    property int pickerHour: 0
    property int pickerMinute: 0
    property bool editingRecurringTask: false
    property var editingRecurrence: ({ frequency: "none", interval: 1, weekdays: [],
                                       endMode: "never", untilDate: "", occurrenceCount: 0 })
    property int editingWeekdayMask: 0
    property var editingReminderMinutesBefore: [0]
    readonly property int maximumReminderCount: 5
    property bool habitEditorVisible: false
    property bool habitManualVisible: false
    property bool habitReminderPickerVisible: false
    property var editingHabitReminderTimes: []
    property string editingHabitId: ""
    property string editingHabitEmoji: ""
    property string manualHabitId: ""
    property int habitWeekdayMask: 127
    readonly property int maximumHabitReminderCount: 10
    readonly property var portugueseLocale: Qt.locale("pt_BR")

    readonly property var barIdentity: hostWidget || root
    readonly property var weeks: Model.monthWeeks(viewYear, viewMonth, occurrences, holidays)
    readonly property bool selectedDateIsToday:
        Model.dateKey(selectedDate) === Model.dateKey(today)
    readonly property var selectedDateTasks: selectedDateIsToday
        ? todayTasks : Model.occurrencesForDate(occurrences, selectedDate)
    readonly property var selectedTasks: selectedDateTasks
    readonly property var selectedHolidays: Model.holidaysForDate(holidays, selectedDate)
    readonly property real yearDone: Model.yearProgress(today)
    readonly property int yearDonePercent: Math.round(yearDone * 100)
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property int cellWidth: Style.space(52)
    readonly property int cellHeight: Style.space(34)
    readonly property int cellSpacing: Style.space(2)
    readonly property int weekColumnWidth: Style.space(32)
    readonly property int gutterWidth: Style.space(14)
    readonly property color optionalHolidayColor: "#8ba9ff"

    function holidayColor(kind) {
        if (kind === "legal")
            return Color.urgent;
        if (kind === "optional")
            return optionalHolidayColor;
        return Color.accent;
    }

    function holidayKindLabel(kind, scope) {
        let category = "DATA COMEMORATIVA";
        if (kind === "legal")
            category = "FERIADO";
        else if (kind === "optional")
            category = "PONTO FACULTATIVO";

        let coverage = "";
        if (scope === "national")
            coverage = "NACIONAL";
        else if (scope === "state")
            coverage = "ESTADUAL";
        else if (scope === "municipal")
            coverage = "MUNICIPAL";
        return coverage === "" ? category : category + " " + coverage;
    }

    function categoryOptions() {
        const options = [{ label: "Entrada", value: "", color: Color.accent }];
        for (const category of categories || []) {
            options.push({
                label: String(category.name || ""),
                value: String(category.id || ""),
                color: String(category.color || Color.accent)
            });
        }
        return options;
    }
    function requestCompletion(task, editDate) {
        if (!hostWidget || hostWidget.actionBusy)
            return;
        if (!editDate && (task.completed || task.skipped)) {
            hostWidget.setOccurrenceCompleted(task.taskId, task.occurrenceDate, false, "");
            return;
        }
        const todayKey = Model.dateKey(new Date());
        if (!editDate && task.occurrenceDate >= todayKey) {
            hostWidget.setOccurrenceCompleted(task.taskId, task.occurrenceDate, true, todayKey);
            return;
        }
        completionTask = task;
        completionDateInput.text = String(task.completedDate || todayKey);
        completionCustomDateVisible = editDate;
        completionPickerVisible = true;
    }

    function saveCompletion(dateKey) {
        if (!hostWidget || !completionTask)
            return;
        if (hostWidget.setOccurrenceCompleted(completionTask.taskId,
                completionTask.occurrenceDate, true, dateKey,
                completionTask.completed ? String(completionTask.completedDate || "") : null))
            completionPickerVisible = false;
    }

    function completionSaved(action) {
        completionFeedback = !action.completed ? "Conclusão desfeita"
            : action.previousCompletedDate !== null ? "Data da conclusão alterada"
            : "Conclusão salva";
        completionUndo = action.completed ? action : null;
        completionFeedbackTimer.restart();
    }

    function undoCompletion() {
        if (!hostWidget || !completionUndo)
            return;
        if (completionUndo.previousCompletedDate) {
            hostWidget.setOccurrenceCompleted(completionUndo.taskId,
                completionUndo.occurrenceDate, true, completionUndo.previousCompletedDate,
                completionUndo.completedDate);
        } else {
            hostWidget.setOccurrenceCompleted(completionUndo.taskId,
                completionUndo.occurrenceDate, false, "");
        }
    }

    function toggleActivityTask(taskId) {
        const expanded = Object.assign({}, expandedActivityTasks);
        expanded[taskId] = !expanded[taskId];
        expandedActivityTasks = expanded;
    }



    function open() {
        today = new Date();
        selectedDate = today;
        viewYear = selectedDate.getFullYear();
        viewMonth = selectedDate.getMonth();
        if (hostWidget) {
            hostWidget.refreshRange(viewYear, viewMonth);
            hostWidget.refreshHabits(Model.dateKey(selectedDate));
            hostWidget.refreshRegistrationActivity(Model.dateKey(selectedDate));
        }
        controller.show();
    }

    function close() {
        controller.hide();
    }

    function toggle() {
        if (opened)
            close();
        else
            open();
    }

    function moveMonth(delta) {
        const next = new Date(viewYear, viewMonth + delta, 1);
        viewYear = next.getFullYear();
        viewMonth = next.getMonth();
        if (hostWidget)
            hostWidget.refreshRange(viewYear, viewMonth);
    }

    function selectDay(date) {
        selectedDate = date;
        registrationActivityExpanded = false;
        expandedActivityTasks = ({});
        if (hostWidget) {
            hostWidget.refreshHabits(Model.dateKey(selectedDate));
            hostWidget.refreshRegistrationActivity(Model.dateKey(selectedDate));
        }
        if (date.getMonth() !== viewMonth || date.getFullYear() !== viewYear) {
            viewMonth = date.getMonth();
            viewYear = date.getFullYear();
            if (hostWidget)
                hostWidget.refreshRange(viewYear, viewMonth);
        }
        Qt.callLater(() => quickAdd.forceActiveFocus());
    }

    function padTimePart(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function currentTimeKey() {
        return Qt.formatTime(new Date(), "HH:mm");
    }

    function syncPickerSelectionFromText() {
        if (!timePickerInput.acceptableInput)
            return;
        const parts = timePickerInput.text.split(":");
        pickerHour = Number(parts[0]);
        pickerMinute = Number(parts[1]);
    }

    function updatePickerText() {
        timePickerInput.text = padTimePart(pickerHour) + ":" + padTimePart(pickerMinute);
    }

    function openTimePicker(target, initialTime) {
        timePickerTarget = target;
        timePickerAddsHabitReminder = false;
        timePickerInput.text = initialTime || currentTimeKey();
        syncPickerSelectionFromText();
        timePickerVisible = true;
        Qt.callLater(() => timePickerConfirm.forceActiveFocus());
    }

    function selectCurrentPickerTime() {
        const now = new Date();
        pickerHour = now.getHours();
        pickerMinute = now.getMinutes();
        updatePickerText();
    }

    function choosePickerHour(hour) {
        pickerHour = hour;
        updatePickerText();
    }

    function choosePickerMinute(minute) {
        pickerMinute = minute;
        updatePickerText();
    }

    function closeTimePicker() {
        timePickerVisible = false;
        timePickerTarget = null;
        timePickerAddsHabitReminder = false;
    }

    function openEmojiPicker(target, currentEmoji) {
        emojiPickerTarget = target;
        emojiPicker.openPicker(currentEmoji);
    }

    function applyEmoji(selectedEmoji) {
        if (emojiPickerTarget === "edit")
            editingEmoji = selectedEmoji;
        else if (emojiPickerTarget === "habit")
            editingHabitEmoji = selectedEmoji;
        emojiPickerTarget = "";
    }

    function applyTimePicker() {
        if (!timePickerInput.acceptableInput)
            return;
        const selectedTime = timePickerInput.text;
        if (creatingTask && taskEditorVisible) {
            taskTimeInput.text = selectedTime;
            saveTaskEdit();
            return;
        }
        if (timePickerAddsHabitReminder) {
            addHabitReminder(selectedTime);
            timePickerVisible = false;
            timePickerAddsHabitReminder = false;
            return;
        }
        if (timePickerTarget)
            timePickerTarget.text = selectedTime;
        closeTimePicker();
    }

    function beginQuickTask() {
        const title = quickAdd.text.trim();
        if (title === "" || !hostWidget || creationPending || hostWidget.actionBusy)
            return;
        if (!quickDraft)
            pendingQuickDate = new Date(selectedDate.getTime());
        const draft = quickDraft || { scheduledTime: currentTimeKey() };
        draft.title = title;
        openTaskEditor(draft, true);
        timePickerInput.text = taskTimeInput.text;
        timePickerAddsHabitReminder = false;
        syncPickerSelectionFromText();
    }
    function taskAnchorWeekdayIndex() {
        return ((creatingTask ? pendingQuickDate : selectedDate).getDay() + 6) % 7;
    }

    function taskRecurrencePresetValue() {
        const frequency = String(editingRecurrence.frequency || "none");
        if (frequency === "none")
            return "none";
        const standard = Number(editingRecurrence.interval || 1) === 1
                      && (editingRecurrence.weekdays || []).length === 0
                      && String(editingRecurrence.endMode || "never") === "never";
        return standard ? frequency : "custom";
    }

    function selectedTaskWeekdays() {
        if (taskRecurrenceInput.value !== "custom"
                || taskCustomFrequency.value !== "weekly")
            return [];
        const selected = [];
        for (let index = 0; index < 7; ++index) {
            if ((editingWeekdayMask & (1 << index)) !== 0)
                selected.push(index + 1);
        }
        return selected;
    }

    function setEditingReminders(values) {
        const normalized = [];
        for (const value of (values || [])) {
            const minutes = Number(value);
            if (minutes >= 0 && Math.floor(minutes) === minutes
                    && normalized.indexOf(minutes) < 0
                    && normalized.length < maximumReminderCount)
                normalized.push(minutes);
        }
        normalized.sort((left, right) => right - left);
        editingReminderMinutesBefore = normalized;
    }

    function containsEditingReminder(minutes) {
        return editingReminderMinutesBefore.indexOf(minutes) >= 0;
    }

    function toggleEditingReminder(minutes) {
        const updated = editingReminderMinutesBefore.slice();
        const index = updated.indexOf(minutes);
        if (index >= 0)
            updated.splice(index, 1);
        else if (updated.length < maximumReminderCount)
            updated.push(minutes);
        setEditingReminders(updated);
    }

    function reminderLabel(minutes) {
        if (minutes === 0)
            return "No horário";
        if (minutes % 10080 === 0) {
            const weeks = minutes / 10080;
            return weeks === 1 ? "1 semana antes" : weeks + " semanas antes";
        }
        if (minutes % 1440 === 0) {
            const days = minutes / 1440;
            return days === 1 ? "1 dia antes" : days + " dias antes";
        }
        if (minutes % 60 === 0) {
            const hours = minutes / 60;
            return hours === 1 ? "1 hora antes" : hours + " horas antes";
        }
        return minutes === 1 ? "1 minuto antes" : minutes + " minutos antes";
    }

    function addCustomReminder() {
        const minutes = reminderCustomAmount.value * Number(reminderCustomUnit.value);
        if (!containsEditingReminder(minutes)
                && editingReminderMinutesBefore.length < maximumReminderCount)
            toggleEditingReminder(minutes);
    }

    function closeReminderPicker() {
        reminderPickerVisible = false;
    }

    function preserveQuickDraft() {
        if (timePickerInput.acceptableInput)
            taskTimeInput.text = timePickerInput.text;
        quickAdd.text = taskTitleInput.text;
        quickDraft = {
            title: taskTitleInput.text, scheduledTime: taskTimeInput.text,
            emoji: editingEmoji, categoryId: editingCategoryId,
            reminderMinutesBefore: editingReminderMinutesBefore.slice(),
            recurrence: taskEditorRecurrence()
        };
    }

    function taskCreationFinished(succeeded) {
        creationPending = false;
        if (!succeeded)
            return;
        taskEditorVisible = false;
        creatingTask = false;
        quickDraft = null;
        quickAdd.text = "";
        Qt.callLater(() => quickAdd.forceActiveFocus());
    }

    function openTaskEditor(task, createsTask) {
        creatingTask = createsTask === true;
        taskMoreOptions = !creatingTask;
        editedTask = task;
        editingTaskId = String(task.taskId || "");
        editingOccurrenceDate = String(task.occurrenceDate || "");
        editingCompleted = task.completed === true;
        editingSkipped = task.skipped === true;
        taskTitleInput.text = String(task.title || "");
        taskTimeInput.text = String(task.scheduledTime || "");
        editingEmoji = String(task.emoji || "");
        editingCategoryId = String(task.categoryId || "");
        setEditingReminders(task.reminderMinutesBefore || [0]);
        editingRecurrence = task.recurrence || ({ frequency: "none", interval: 1, weekdays: [],
                                                  endMode: "never", untilDate: "",
                                                  occurrenceCount: 0 });
        const frequency = String(editingRecurrence.frequency || "none");
        taskCustomFrequency.value = frequency === "none" ? "daily" : frequency;
        taskCustomInterval.value = Number(editingRecurrence.interval || 1);
        editingWeekdayMask = 0;
        for (const weekday of (editingRecurrence.weekdays || []))
            editingWeekdayMask |= 1 << (Number(weekday) - 1);
        if (frequency === "weekly" && editingWeekdayMask === 0)
            editingWeekdayMask = 1 << taskAnchorWeekdayIndex();
        taskCustomEnding.value = String(editingRecurrence.endMode || "never");
        taskCustomUntilDate.text = String(editingRecurrence.untilDate
                                         || Model.dateKey(creatingTask ? pendingQuickDate : selectedDate));
        taskCustomOccurrenceCount.value =
            Math.max(1, Number(editingRecurrence.occurrenceCount || 10));
        taskRecurrenceInput.value = taskRecurrencePresetValue();
        editingRecurringTask = task.recurring === true;
        taskEditorVisible = true;
        Qt.callLater(() => {
            if (creatingTask) {
                timePickerConfirm.forceActiveFocus();
            } else {
                taskTitleInput.forceActiveFocus();
                taskTitleInput.selectAll();
            }
        });
    }

    function closeTaskEditor() {
        if (creationPending)
            return;
        if (creatingTask)
            preserveQuickDraft();
        taskDatePickerVisible = false;
        taskEditorVisible = false;
    }

    function taskEditorRecurrence() {
        const custom = taskRecurrenceInput.value === "custom";
        const frequency = custom ? taskCustomFrequency.value : taskRecurrenceInput.value;
        const endMode = custom ? taskCustomEnding.value : "never";
        return {
            frequency: frequency,
            interval: custom ? taskCustomInterval.value : 1,
            weekdays: selectedTaskWeekdays(),
            endMode: endMode,
            untilDate: endMode === "onDate" ? taskCustomUntilDate.text.trim() : "",
            occurrenceCount: endMode === "afterCount" ? taskCustomOccurrenceCount.value : 0
        };
    }

    function taskOptionsSummary() {
        const list = categoryOptions().find(option => option.value === editingCategoryId);
        const recurrence = taskEditorRecurrence();
        const labels = { none: "Não repetir", daily: "Diária", weekly: "Semanal",
                         monthly: "Mensal", yearly: "Anual" };
        let repeat = labels[recurrence.frequency];
        if (recurrence.frequency !== "none") {
            repeat += " · intervalo " + recurrence.interval;
            if (recurrence.weekdays.length)
                repeat += " · " + recurrence.weekdays.map(day =>
                    ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"][day - 1]).join(", ");
            if (recurrence.endMode === "onDate")
                repeat += " · até " + portugueseLocale.toString(
                    Model.parseLocalDate(recurrence.untilDate), "dd/MM/yyyy");
            else if (recurrence.endMode === "afterCount")
                repeat += " · " + recurrence.occurrenceCount + " ocorrências";
        }
        const reminders = editingReminderMinutesBefore.length
            ? editingReminderMinutesBefore.map(value => reminderLabel(value)).join(", ")
            : "Sem notificações";
        return (editingEmoji ? editingEmoji + " · " : "")
            + (list ? list.label : "Entrada") + "\n" + reminders + "\n" + repeat;
    }

    function openTaskDatePicker(forEnding) {
        taskDatePickerForEnding = forEnding;
        const date = forEnding ? Model.parseLocalDate(taskCustomUntilDate.text) : pendingQuickDate;
        taskPickerMonth = new Date(date.getFullYear(), date.getMonth(), 1);
        taskDatePickerVisible = true;
    }

    function chooseTaskDate(date) {
        if (taskDatePickerForEnding)
            taskCustomUntilDate.text = Model.dateKey(date);
        else
            pendingQuickDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        taskDatePickerVisible = false;
        if (creatingTask)
            Qt.callLater(() => timePickerConfirm.forceActiveFocus());
    }

    function saveTaskEdit() {
        const title = taskTitleInput.text.trim();
        const time = taskTimeInput.text.trim();
        if (title === "" || !taskTimeInput.acceptableInput || !hostWidget
                || hostWidget.actionBusy || creationPending)
            return;
        const recurrence = taskEditorRecurrence();
        if (creatingTask) {
            preserveQuickDraft();
            creationPending = hostWidget.addTask(title, pendingQuickDate, time,
                editingReminderMinutesBefore, editingEmoji, editingCategoryId, recurrence);
            return;
        }
        hostWidget.editTask(editingTaskId, title, time, recurrence,
                            editingReminderMinutesBefore, editingEmoji, editingCategoryId);
        closeTaskEditor();
    }
    function deleteEditedTask() {
        if (!hostWidget)
            return;
        hostWidget.deleteTask(editingTaskId);
        closeTaskEditor();
    }
    function skipEditedOccurrence() {
        if (!hostWidget)
            return;
        hostWidget.skipOccurrence(editingTaskId, editingOccurrenceDate);
        closeTaskEditor();
    }
    function reopenEditedOccurrence() {
        if (!hostWidget)
            return;
        hostWidget.setOccurrenceCompleted(editingTaskId, editingOccurrenceDate, false, "");
        closeTaskEditor();
    }

    function selectedHabitWeekdays() {
        const selected = [];
        for (let index = 0; index < 7; ++index) {
            if ((habitWeekdayMask & (1 << index)) !== 0)
                selected.push(index + 1);
        }
        return selected;
    }

    function setHabitReminders(values) {
        const normalized = [];
        for (const value of (values || [])) {
            const time = String(value);
            if (/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time)
                    && normalized.indexOf(time) < 0
                    && normalized.length < maximumHabitReminderCount)
                normalized.push(time);
        }
        normalized.sort();
        editingHabitReminderTimes = normalized;
    }

    function addHabitReminder(time) {
        const updated = editingHabitReminderTimes.slice();
        if (updated.indexOf(time) < 0 && updated.length < maximumHabitReminderCount) {
            updated.push(time);
            setHabitReminders(updated);
        }
    }

    function removeHabitReminder(time) {
        const updated = editingHabitReminderTimes.slice();
        const index = updated.indexOf(time);
        if (index >= 0)
            updated.splice(index, 1);
        setHabitReminders(updated);
    }

    function openHabitReminderTimePicker() {
        timePickerTarget = null;
        timePickerAddsHabitReminder = true;
        timePickerInput.text = currentTimeKey();
        syncPickerSelectionFromText();
        timePickerVisible = true;
    }

    function openHabitEditor(habit) {
        const source = habit || ({});
        editingHabitId = String(source.id || "");
        editingHabitEmoji = String(source.emoji || "");
        habitTitleInput.text = String(source.title || "");
        habitGoalInput.value = Number(source.targetAmount || 1);
        habitUnitInput.text = String(source.unit || "");
        habitModeInput.value = String(source.checkInMode || "complete");
        habitIncrementInput.value = Number(source.incrementAmount || 1);
        habitWeekdayMask = 0;
        for (const weekday of (source.weekdays || [1, 2, 3, 4, 5, 6, 7]))
            habitWeekdayMask |= 1 << (Number(weekday) - 1);
        setHabitReminders(source.reminderTimes || []);
        habitEditorVisible = true;
        Qt.callLater(() => {
            habitTitleInput.forceActiveFocus();
            habitTitleInput.selectAll();
        });
    }

    function closeHabitEditor() {
        habitEditorVisible = false;
        habitReminderPickerVisible = false;
    }

    function saveHabitEdit() {
        if (!hostWidget || habitTitleInput.text.trim() === "" || habitWeekdayMask === 0)
            return;
        const reminders = editingHabitReminderTimes;
        hostWidget.saveHabit({
            id: editingHabitId,
            title: habitTitleInput.text.trim(),
            targetAmount: habitGoalInput.value,
            unit: habitUnitInput.text.trim(),
            checkInMode: habitModeInput.value,
            incrementAmount: habitIncrementInput.value,
            weekdays: selectedHabitWeekdays(),
            reminderTimes: reminders,
            emoji: editingHabitEmoji
        });
        closeHabitEditor();
    }

    function deleteEditedHabit() {
        if (hostWidget)
            hostWidget.deleteHabit(editingHabitId);
        closeHabitEditor();
    }

    function openManualHabit(habitId) {
        manualHabitId = habitId;
        habitManualAmount.value = 1;
        habitManualVisible = true;
        Qt.callLater(() => habitManualRegister.forceActiveFocus());
    }

    function recordManualHabit() {
        if (hostWidget)
            hostWidget.recordHabit(
                manualHabitId, Model.dateKey(selectedDate), habitManualAmount.value);
        habitManualVisible = false;
    }



    Timer {
        id: completionFeedbackTimer
        interval: 8000
        onTriggered: {
            root.completionFeedback = "";
            root.completionUndo = null;
        }
    }

    KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: true
        focusTarget: keyCatcher
        contentWidth: popup.fittedContentWidth(Style.space(1120))
        contentHeight: popup.fittedContentHeight(Math.max(contentColumn.implicitHeight,
            root.taskEditorVisible ? taskEditorColumn.implicitHeight + Style.space(64) : 0))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onMoveRequested: function (dx, dy) {
                if (dx !== 0 && !root.taskEditorVisible)
                    root.moveMonth(dx);
            }
            onActivateRequested: {
                if (!root.taskEditorVisible)
                    quickAdd.forceActiveFocus();
            }
            onCloseRequested: {
                if (root.taskDatePickerVisible)
                    root.taskDatePickerVisible = false;
                else if (root.reminderPickerVisible)
                    root.closeReminderPicker();
                else if (root.timePickerVisible)
                    root.closeTimePicker();
                else if (root.taskEditorVisible)
                    root.closeTaskEditor();
                else if (root.completionPickerVisible)
                    root.completionPickerVisible = false;
                else
                    root.close();
            }

            Flickable {
                id: panelFlick
                anchors.fill: parent
                contentWidth: contentColumn.width
                contentHeight: contentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                readonly property bool wideLayout: width >= Style.space(1000)
                    && popup.fittedContentHeight(Style.space(720)) >= Style.space(600)
                interactive: !wideLayout
                onWideLayoutChanged: {
                    contentY = 0;
                    if (detailsFlick)
                        detailsFlick.contentY = 0;
                    if (habitsFlick)
                        habitsFlick.contentY = 0;
                }

                Item {
                    id: contentColumn
                    width: panelFlick.width
                    implicitHeight: panelFlick.wideLayout
                        ? Math.max(calendarColumn.implicitHeight + Style.space(16)
                                   + Math.min(habitsColumn.implicitHeight, Style.space(250)),
                                   Math.min(detailsColumn.implicitHeight, Style.space(720)))
                        : calendarColumn.implicitHeight + habitsColumn.implicitHeight
                          + Style.space(32) + detailsColumn.implicitHeight

                    Column {
                        id: calendarColumn
                        width: panelFlick.wideLayout ? (parent.width - Style.space(24)) / 2 : parent.width
                        spacing: Style.space(8)
                    Text {
                        width: parent.width
                        visible: root.loadError !== ""
                        text: root.loadError
                        color: Color.urgent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.Wrap
                    }

                    Item {
                        width: parent.width
                        height: heroRow.height

                        Row {
                            id: heroRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Style.space(22)

                            Text {
                                anchors.baseline: heroDate.baseline
                                text: "󰃭"
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: 48
                            }

                            Text {
                                id: heroDate
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.portugueseLocale.toString(root.selectedDate, "d 'de' MMMM")
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: 52
                                font.bold: true
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: yearBlock.y + yearBlock.height

                        Item {
                            id: yearBlock
                            y: Style.space(6)
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: calendarGridColumn.width
                            height: Math.max(yearLabel.implicitHeight, Style.space(10))

                            Text {
                                id: yearLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.today.getFullYear()
                                color: Qt.darker(root.foreground, 1.5)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.bodySmall
                                font.letterSpacing: 1
                            }

                            Text {
                                id: yearPercent
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.yearDonePercent + "%"
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.bodySmall
                            }

                            Rectangle {
                                anchors.left: yearLabel.right
                                anchors.right: yearPercent.left
                                anchors.leftMargin: Style.space(12)
                                anchors.rightMargin: Style.space(12)
                                anchors.verticalCenter: parent.verticalCenter
                                height: Style.space(6)
                                radius: Style.cornerRadius > 0 ? height / 2 : 0
                                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                                Rectangle {
                                    width: Math.round(parent.width * root.yearDone)
                                    height: parent.height
                                    radius: parent.radius
                                    color: Style.selectedStateColor(root.foreground, Color.accent)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: calendarGridColumn.y + calendarGridColumn.height

                        WheelHandler {
                            onWheel: function (event) {
                                if (event.angleDelta.y === 0)
                                    return;
                                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1);
                            }
                        }

                        Column {
                            id: calendarGridColumn
                            y: Style.space(18)
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Style.space(3)

                            Row {
                                id: headerRow
                                spacing: root.cellSpacing

                                Text {
                                    width: root.weekColumnWidth
                                    height: Style.space(16)
                                    text: "S"
                                    color: Qt.darker(root.foreground, 1.9)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    font.letterSpacing: 1
                                }

                                Item {
                                    width: root.gutterWidth
                                    height: Style.space(16)
                                }

                                Repeater {
                                    model: ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"]

                                    Text {
                                        required property string modelData
                                        width: root.cellWidth
                                        height: Style.space(16)
                                        text: modelData
                                        color: Qt.darker(root.foreground, 1.5)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }
                                }
                            }

                            Repeater {
                                model: root.weeks

                                Row {
                                    required property var modelData
                                    spacing: root.cellSpacing

                                    Text {
                                        width: root.weekColumnWidth
                                        height: root.cellHeight
                                        text: modelData.week
                                        color: Qt.darker(root.foreground, 1.9)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                    }

                                    Item {
                                        width: root.gutterWidth
                                        height: root.cellHeight
                                    }

                                    Repeater {
                                        model: modelData.days

                                        Rectangle {
                                            required property var modelData
                                            width: root.cellWidth
                                            height: root.cellHeight
                                            radius: Style.cornerRadius
                                            color: dayMouse.containsMouse || Model.dateKey(root.selectedDate) === modelData.key
                                                ? Style.hoverFillFor(root.foreground, Color.accent)
                                                : "transparent"
                                            border.width: modelData.today ? Style.spacing.hairline : 0
                                            border.color: Style.normalBorderFor(root.foreground, Color.accent)

                                            Text {
                                                anchors.centerIn: parent
                                                anchors.verticalCenterOffset: -2
                                                text: modelData.day
                                                color: modelData.inMonth
                                                    ? (modelData.holidayCount > 0
                                                       ? root.holidayColor(modelData.holidayKind)
                                                       : modelData.weekend ? Qt.darker(root.foreground, 1.45)
                                                                           : root.foreground)
                                                    : Qt.darker(root.foreground, 2.2)
                                                font.family: root.fontFamily
                                                font.pixelSize: Style.font.body
                                                font.bold: modelData.today
                                            }
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: Style.space(4)
                                                visible: modelData.holidayCount > 0
                                                width: modelData.holidayCount > 1 ? Style.space(10) : Style.space(6)
                                                height: Style.spacing.hairline * 2
                                                radius: height / 2
                                                color: root.holidayColor(modelData.holidayKind)
                                            }

                                            ToolTip.visible: dayMouse.containsMouse
                                                                 && modelData.categoryMarkers.length > 0
                                            ToolTip.text: {
                                                const labels = [];
                                                for (const marker of modelData.categoryMarkers)
                                                    labels.push(marker.name);
                                                if (modelData.categoryOverflow > 0)
                                                    labels.push("+" + modelData.categoryOverflow);
                                                return labels.join(", ");
                                            }


                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: Style.space(3)
                                                spacing: Style.space(2)

                                                Text {
                                                    visible: modelData.skipped > 0
                                                    text: modelData.skipped === 1
                                                        ? "×" : "×" + modelData.skipped
                                                    color: Color.urgent
                                                    font.family: root.fontFamily
                                                    font.pixelSize: Style.font.caption
                                                    font.bold: true
                                                }

                                                Repeater {
                                                    model: modelData.categoryMarkers

                                                    Rectangle {
                                                        required property var modelData
                                                        width: Style.space(4)
                                                        height: width
                                                        radius: width / 2
                                                        color: modelData.color
                                                        border.width: modelData.overdue
                                                                      ? Style.spacing.hairline : 0
                                                        border.color: Color.urgent
                                                    }
                                                }

                                                Text {
                                                    visible: modelData.categoryOverflow > 0
                                                    text: "+" + modelData.categoryOverflow
                                                    color: Color.accent
                                                    font.family: root.fontFamily
                                                    font.pixelSize: Style.font.caption
                                                    font.bold: true
                                                }
                                            }

                                            MouseArea {
                                                id: dayMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectDay(modelData.date)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            x: calendarGridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
                            y: calendarGridColumn.y + headerRow.height + calendarGridColumn.spacing
                            width: Style.spacing.hairline
                            height: calendarGridColumn.height - headerRow.height - calendarGridColumn.spacing
                            color: root.foreground
                            opacity: 0.1
                        }
                    }

                    Item {
                        width: parent.width
                        height: monthNavigation.height

                        Item {
                            id: monthNavigation
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: calendarGridColumn.width
                            height: monthLabel.implicitHeight + Style.space(10)

                            Text {
                                id: monthLabel
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.space(130)
                                horizontalAlignment: Text.AlignHCenter
                                text: root.portugueseLocale.toString(new Date(root.viewYear, root.viewMonth, 1), "MMMM 'de' yyyy").toUpperCase()
                                color: Qt.darker(root.foreground, 1.4)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                font.letterSpacing: 1
                            }

                            ToolButton {
                                anchors.left: parent.left
                                anchors.leftMargin: -Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "‹"
                                onClicked: root.moveMonth(-1)
                            }

                            ToolButton {
                                anchors.right: parent.right
                                anchors.rightMargin: -Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                onClicked: root.moveMonth(1)
                            }
                        }
                    }
                    }

                    Flickable {
                        id: habitsFlick
                        interactive: panelFlick.wideLayout
                        y: calendarColumn.implicitHeight + Style.space(16)
                        width: calendarColumn.width
                        height: panelFlick.wideLayout ? Math.max(0, panelFlick.height - y) : habitsColumn.implicitHeight
                        contentWidth: width
                        contentHeight: habitsColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                    Column {
                        id: habitsColumn
                        width: habitsFlick.width
                        spacing: Style.space(3)

                        RowLayout {
                            width: parent.width

                            Text {
                                text: "HÁBITOS"
                                color: Qt.darker(root.foreground, 1.4)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                font.letterSpacing: 1
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "+ HÁBITO"
                                foreground: root.foreground
                                accent: Color.accent
                                bordered: true
                                horizontalPadding: Style.space(7)
                                verticalPadding: Style.space(3)
                                onClicked: root.openHabitEditor(null)
                            }
                        }

                        Text {
                            visible: root.selectedHabits.length === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nenhum hábito para este dia"
                            color: Qt.darker(root.foreground, 1.9)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Repeater {
                            model: root.selectedHabits

                            Rectangle {
                                id: habitRow
                                required property var modelData
                                width: parent.width
                                height: Style.space(66)
                                radius: Style.cornerRadius
                                color: Style.hoverFillFor(root.foreground, Color.accent)

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: habitActions.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: Style.space(8)
                                    anchors.rightMargin: Style.space(6)
                                    spacing: Style.space(3)

                                    Row {
                                        width: parent.width
                                        spacing: Style.space(6)

                                        Text {
                                            visible: String(habitRow.modelData.emoji || "") !== ""
                                            text: habitRow.modelData.emoji || ""
                                            color: root.foreground
                                            font.family: "Noto Color Emoji"
                                            font.pixelSize: Style.font.body
                                        }
                                        Text {
                                            width: parent.width - (visible ? Style.space(28) : 0)
                                            text: habitRow.modelData.title
                                            color: habitRow.modelData.completed
                                                ? Qt.darker(root.foreground, 1.7) : root.foreground
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.body
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: habitRow.modelData.amount + " / " + habitRow.modelData.targetAmount
                                            + (String(habitRow.modelData.unit || "") === ""
                                                ? "" : " " + habitRow.modelData.unit)
                                            + ((habitRow.modelData.reminderTimes || []).length === 0
                                                ? "" : " · 󰂚 " + habitRow.modelData.reminderTimes.length)
                                        color: habitRow.modelData.completed ? Color.accent
                                            : Qt.darker(root.foreground, 1.45)
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: Style.spacing.hairline * 2
                                        radius: height / 2
                                        color: Qt.rgba(root.foreground.r, root.foreground.g,
                                                       root.foreground.b, 0.18)

                                        Rectangle {
                                            width: parent.width * Math.min(
                                                1, habitRow.modelData.amount / habitRow.modelData.targetAmount)
                                            height: parent.height
                                            radius: parent.radius
                                            color: Color.accent
                                        }
                                    }
                                }

                                Row {
                                    id: habitActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: Style.space(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Style.space(3)

                                    Button {
                                        visible: habitRow.modelData.amount > 0
                                        text: "↶"
                                        foreground: root.foreground
                                        accent: Color.accent
                                        bordered: true
                                        horizontalPadding: Style.space(6)
                                        verticalPadding: Style.space(3)
                                        onClicked: if (root.hostWidget)
                                            root.hostWidget.undoHabit(
                                                habitRow.modelData.id, Model.dateKey(root.selectedDate))
                                    }
                                    Button {
                                        text: "⋯"
                                        foreground: root.foreground
                                        accent: Color.accent
                                        bordered: true
                                        horizontalPadding: Style.space(6)
                                        verticalPadding: Style.space(3)
                                        onClicked: root.openHabitEditor(habitRow.modelData)
                                    }
                                    Button {
                                        enabled: !habitRow.modelData.completed
                                        text: habitRow.modelData.completed ? "✓"
                                            : habitRow.modelData.checkInMode === "fixed"
                                                ? "+" + habitRow.modelData.incrementAmount
                                            : habitRow.modelData.checkInMode === "manual" ? "+" : "✓"
                                        foreground: root.foreground
                                        accent: Color.accent
                                        selected: habitRow.modelData.completed
                                        horizontalPadding: Style.space(7)
                                        verticalPadding: Style.space(3)
                                        onClicked: {
                                            if (!root.hostWidget)
                                                return;
                                            if (habitRow.modelData.checkInMode === "manual")
                                                root.openManualHabit(habitRow.modelData.id);
                                            else
                                                root.hostWidget.recordHabit(
                                                    habitRow.modelData.id,
                                                    Model.dateKey(root.selectedDate), 0);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }

                    Flickable {
                        id: detailsFlick
                        x: panelFlick.wideLayout ? calendarColumn.width + Style.space(24) : 0
                        y: panelFlick.wideLayout ? 0 : habitsFlick.y + habitsFlick.height + Style.space(16)
                        width: calendarColumn.width
                        height: panelFlick.wideLayout ? panelFlick.height : detailsColumn.implicitHeight
                        contentWidth: width
                        contentHeight: detailsColumn.implicitHeight
                        interactive: panelFlick.wideLayout
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        Column {
                            id: detailsColumn
                            width: detailsFlick.width
                            spacing: Style.space(8)

                    RowLayout {
                        width: parent.width

                        Text {
                            text: "TAREFAS"
                            color: Qt.darker(root.foreground, 1.4)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Button {
                            text: root.taskVisibility === "pending" ? "PENDENTES" : "TODAS"
                            tooltipText: root.taskVisibility === "pending"
                                ? "Exibindo somente pendentes; clique para mostrar todas"
                                : "Exibindo todas; clique para mostrar somente pendentes"
                            foreground: root.foreground
                            accent: Color.accent
                            bordered: true
                            selected: root.taskVisibility === "pending"
                            horizontalPadding: Style.space(7)
                            verticalPadding: Style.space(3)
                            onClicked: if (root.hostWidget)
                                root.hostWidget.setTaskVisibility(
                                    root.taskVisibility === "pending" ? "all" : "pending")
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.space(42)
                        radius: Style.cornerRadius
                        color: Style.hoverFillFor(root.foreground, Color.accent)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(10)
                            spacing: Style.space(4)

                            TextField {
                                id: quickAdd
                                objectName: "waypointQuickTaskTitle"
                                Layout.fillWidth: true
                                placeholderText: "Nova tarefa em " + root.portugueseLocale.toString(
                                    root.quickDraft ? root.pendingQuickDate : root.selectedDate,
                                    "d 'de' MMM") + "…"
                                color: root.foreground
                                placeholderTextColor: Qt.darker(root.foreground, 1.8)
                                font.family: root.fontFamily
                                background: Item {}
                                onAccepted: root.beginQuickTask()
                            }
                        }
                    }


                    Column {
                        width: parent.width
                        spacing: Style.space(3)
                        visible: root.selectedHolidays.length > 0

                        Repeater {
                            model: root.selectedHolidays

                            Rectangle {
                                required property var modelData
                                width: parent.width
                                height: holidayDetails.implicitHeight + Style.space(14)
                                radius: Style.cornerRadius
                                color: Style.hoverFillFor(root.foreground,
                                                         root.holidayColor(modelData.kind))

                                Column {
                                    id: holidayDetails
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(8)
                                    spacing: Style.space(2)

                                    Text {
                                        width: parent.width
                                        text: modelData.name
                                        color: root.holidayColor(modelData.kind)
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.body
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.holidayKindLabel(modelData.kind, modelData.scope)
                                        color: root.holidayColor(modelData.kind)
                                        opacity: 0.72
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                    }


                                    Text {
                                        width: parent.width
                                        visible: String(modelData.description || "") !== ""
                                        text: modelData.description || ""
                                        color: Qt.darker(root.foreground, 1.5)
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.caption
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Style.space(2)

                        Repeater {
                            model: root.selectedTasks

                            Rectangle {
                                id: taskRow
                                required property var modelData
                                readonly property bool overdue:
                                    !modelData.completed && !modelData.skipped
                                    && String(modelData.occurrenceDate || "") < Model.dateKey(root.today)
                                width: parent.width
                                height: Math.max(Style.space(58), taskDetails.implicitHeight + Style.space(12))
                                radius: Style.cornerRadius
                                color: taskMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"


                                Rectangle {
                                    visible: String(modelData.categoryName || "") !== ""
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Style.spacing.hairline * 2
                                    radius: width / 2
                                    color: modelData.categoryColor || Color.accent
                                }
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(50)
                                    spacing: Style.space(8)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.completed ? "󰄲"
                                            : modelData.skipped ? "×" : "󰄱"
                                        color: modelData.completed ? Color.accent
                                             : modelData.skipped ? Color.urgent : root.foreground
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.body
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Style.space(26)
                                        visible: String(modelData.emoji || "") !== ""
                                        text: modelData.emoji || ""
                                        font.family: "Noto Color Emoji"
                                        font.pixelSize: Style.font.body
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Column {
                                        id: taskDetails
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                               - Style.space(String(modelData.emoji || "") === ""
                                                             ? 40 : 74)
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: modelData.title
                                            color: modelData.completed ? Qt.darker(root.foreground, 1.8)
                                                 : modelData.skipped ? Color.urgent : root.foreground
                                            elide: Text.ElideRight
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.body
                                            font.strikeout: modelData.completed
                                        }
                                        Text {
                                            width: parent.width
                                            visible: String(modelData.categoryName || "") !== ""
                                            text: String(modelData.categoryName || "").toUpperCase()
                                            color: modelData.completed
                                                   ? Qt.darker(root.foreground, 1.8)
                                                   : modelData.categoryColor || Color.accent
                                            elide: Text.ElideRight
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                        }
                                        Text {
                                            width: parent.width
                                            text: {
                                                if (modelData.completed)
                                                    return modelData.completionLabel || "";
                                                const time = String(modelData.scheduledTime || "");
                                                const recurrence = String(modelData.recurrenceLabel || "");
                                                const reminderCount =
                                                    (modelData.reminderMinutesBefore || []).length;
                                                const reminder = reminderCount > 0
                                                    ? " · 󰂚 " + reminderCount : "";
                                                const details = (recurrence === ""
                                                    ? time : time + " · " + recurrence) + reminder;
                                                if (modelData.skipped) {
                                                    const date = root.portugueseLocale.toString(
                                                        Model.parseLocalDate(modelData.occurrenceDate),
                                                        "dd MMM").toUpperCase();
                                                    return "NÃO FEITA · " + date + " · " + details;
                                                }
                                                if (!taskRow.overdue)
                                                    return details;
                                                const date = root.portugueseLocale.toString(
                                                    Model.parseLocalDate(modelData.occurrenceDate),
                                                    "dd MMM").toUpperCase();
                                                return "ATRASADA · " + date + " · " + details;
                                            }
                                            color: modelData.completed
                                                ? (modelData.completionLate ? root.completionLateColor
                                                   : Qt.darker(root.foreground, 1.5))
                                                : modelData.skipped || taskRow.overdue
                                                  ? Color.urgent : Color.accent
                                            wrapMode: Text.Wrap
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                        }
                                    }
                                }
                                ToolButton {
                                    id: taskActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: Style.space(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Style.space(34)
                                    height: Style.space(34)
                                    z: 2
                                    text: "⋯"
                                    onClicked: root.openTaskEditor(modelData)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Editar ou excluir tarefa"

                                    background: Rectangle {
                                        radius: Style.cornerRadius
                                        color: taskActions.hovered
                                            ? Style.hoverFillFor(root.foreground, Color.accent)
                                            : "transparent"
                                        border.width: Style.spacing.hairline
                                        border.color: taskActions.hovered || taskActions.activeFocus
                                            ? Color.accent
                                            : Qt.rgba(root.foreground.r, root.foreground.g,
                                                      root.foreground.b, 0.38)
                                    }
                                }

                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: root.openTaskEditor(modelData)
                                }


                                MouseArea {
                                    id: taskMouse
                                    anchors.fill: parent
                                    anchors.rightMargin: Style.space(50)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.hostWidget && !root.hostWidget.actionBusy
                                    onClicked: root.requestCompletion(modelData, false)
                                }
                            }
                        }

                        Text {
                            visible: root.selectedTasks.length === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.loadError !== "" ? root.loadError : "Nenhuma tarefa para este dia"
                            color: root.loadError !== "" ? Color.urgent : Qt.darker(root.foreground, 1.9)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Style.space(6)
                        visible: root.selectedRegistrationActivity.length > 0

                        Button {
                            width: parent.width
                            text: (root.registrationActivityExpanded ? "▾ " : "▸ ")
                                  + "CONCLUSÕES REGISTRADAS NESTE DIA"
                            foreground: Qt.darker(root.foreground, 1.4)
                            accent: Color.accent
                            bordered: false
                            onClicked: root.registrationActivityExpanded =
                                           !root.registrationActivityExpanded
                        }

                        Repeater {
                            model: root.registrationActivityExpanded
                                   ? root.selectedRegistrationActivity : []

                            Column {
                                id: activityGroup
                                required property var modelData
                                width: parent.width
                                spacing: Style.space(4)

                                Button {
                                    width: parent.width
                                    text: (root.expandedActivityTasks[activityGroup.modelData.taskId]
                                           ? "▾ " : "▸ ")
                                          + (activityGroup.modelData.emoji
                                             ? activityGroup.modelData.emoji + " " : "")
                                          + activityGroup.modelData.title + " · "
                                          + activityGroup.modelData.count
                                    foreground: root.foreground
                                    accent: Color.accent
                                    bordered: false
                                    onClicked: root.toggleActivityTask(activityGroup.modelData.taskId)
                                }
                                Text {
                                    width: parent.width
                                    text: activityGroup.modelData.dateSummary
                                    color: Qt.darker(root.foreground, 1.5)
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.caption
                                    wrapMode: Text.Wrap
                                }
                                Repeater {
                                    model: root.expandedActivityTasks[activityGroup.modelData.taskId]
                                           ? activityGroup.modelData.occurrences : []

                                    RowLayout {
                                        id: activityOccurrence
                                        required property var modelData
                                        width: activityGroup.width
                                        spacing: Style.space(6)

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                Layout.fillWidth: true
                                                text: "PREVISTA PARA " + root.portugueseLocale.toString(
                                                    Model.parseLocalDate(activityOccurrence.modelData.occurrenceDate),
                                                    "dd MMM yyyy").toUpperCase()
                                                color: Qt.darker(root.foreground, 1.5)
                                                font.family: root.fontFamily
                                                font.pixelSize: Style.font.caption
                                                wrapMode: Text.Wrap
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: activityOccurrence.modelData.completionLabel
                                                color: activityOccurrence.modelData.completionLate
                                                       ? root.completionLateColor
                                                       : Qt.darker(root.foreground, 1.5)
                                                font.family: root.fontFamily
                                                font.pixelSize: Style.font.caption
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                        Button {
                                            text: "Alterar data"
                                            tooltipText: "Alterar data da conclusão"
                                            foreground: root.foreground
                                            accent: Color.accent
                                            bordered: false
                                            enabled: root.hostWidget && !root.hostWidget.actionBusy
                                            onClicked: root.requestCompletion(
                                                           activityOccurrence.modelData, true)
                                        }
                                        Button {
                                            text: "Desfazer"
                                            tooltipText: "Desfazer conclusão"
                                            foreground: root.foreground
                                            accent: Color.accent
                                            bordered: false
                                            enabled: root.hostWidget && !root.hostWidget.actionBusy
                                            onClicked: root.requestCompletion(
                                                           activityOccurrence.modelData, false)
                                        }
                                    }
                                }
                            }
                        }
                    }


                    RowLayout {
                        width: parent.width

                        Rectangle {
                            Layout.preferredWidth: Style.space(6)
                            Layout.preferredHeight: Style.space(6)
                            radius: width / 2
                            color: root.syncStatus.state === "ready" ? Color.accent
                                  : root.syncStatus.state === "error" ? Color.urgent
                                  : Qt.darker(root.foreground, 1.8)
                        }

                        Text {
                            text: root.syncStatus.state === "ready" ? "Sincronizado"
                                : root.syncStatus.state === "syncing" ? "Sincronizando…"
                                : root.syncStatus.state === "error" ? "Erro de sincronização"
                                : "Somente local"
                            color: Qt.darker(root.foreground, 1.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Text {
                            visible: String(root.updateStatus.currentVersion || "") !== ""
                            text: "v" + root.updateStatus.currentVersion
                            color: Qt.darker(root.foreground, 1.7)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Button {
                            visible: root.updateStatus.state === "available"
                                     && root.updateStatus.canInstall === true
                            text: "Atualizar para " + root.updateStatus.latestVersion
                            foreground: root.foreground
                            accent: Color.accent
                            selected: true
                            horizontalPadding: Style.space(7)
                            verticalPadding: Style.space(3)
                            onClicked: if (root.hostWidget)
                                root.hostWidget.installUpdate()
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        PanelActionButton {
                            iconText: "󰒓"
                            tooltipText: "Configurações do Waypoint"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            onClicked: if (root.hostWidget)
                                root.hostWidget.openSettings()
                        }
                    }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 120
                visible: root.habitEditorVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeHabitEditor()
                }

                BorderSurface {
                    id: habitEditorCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(460))
                    height: contentTopInset + contentBottomInset + habitEditorColumn.implicitHeight
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        id: habitEditorColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: habitEditorCard.contentLeftInset
                        anchors.rightMargin: habitEditorCard.contentRightInset
                        spacing: Style.space(9)

                        Text {
                            text: root.editingHabitId === "" ? "NOVO HÁBITO" : "EDITAR HÁBITO"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            Button {
                                text: root.editingHabitEmoji === "" ? "☺" : root.editingHabitEmoji
                                tooltipText: "Escolher emoji"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                fontFamily: root.editingHabitEmoji === ""
                                            ? root.fontFamily : "Noto Color Emoji"
                                onClicked: root.openEmojiPicker("habit", root.editingHabitEmoji)
                            }
                            TextField {
                                id: habitTitleInput
                                Layout.fillWidth: true
                                placeholderText: "Título"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selectByMouse: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            NumberField {
                                id: habitGoalInput
                                Layout.fillWidth: true
                                from: 1
                                to: 1000000000
                                value: 1
                                foreground: Color.popups.text
                                accent: Color.accent
                                onModified: updatedValue => value = updatedValue
                            }
                            TextField {
                                id: habitUnitInput
                                Layout.fillWidth: true
                                placeholderText: "Unidade (ml, copos…)"
                                maximumLength: 32
                                foreground: Color.popups.text
                                accent: Color.accent
                                selectByMouse: true
                            }
                        }

                        Dropdown {
                            id: habitModeInput
                            Layout.fillWidth: true
                            showLabel: false
                            foreground: Color.popups.text
                            background: Color.popups.background
                            accent: Color.accent
                            options: [
                                { label: "Incremento fixo", value: "fixed" },
                                { label: "Quantidade manual", value: "manual" },
                                { label: "Completar tudo", value: "complete" }
                            ]
                        }

                        RowLayout {
                            visible: habitModeInput.value === "fixed"
                            Layout.fillWidth: true
                            Text {
                                text: "Incremento"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            Item { Layout.fillWidth: true }
                            NumberField {
                                id: habitIncrementInput
                                from: 1
                                to: 1000000000
                                value: 1
                                foreground: Color.popups.text
                                accent: Color.accent
                                onModified: updatedValue => value = updatedValue
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(2)

                            Text {
                                text: "Dias"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: ["S", "T", "Q", "Q", "S", "S", "D"]
                                Button {
                                    required property int index
                                    required property string modelData
                                    text: modelData
                                    selected: (root.habitWeekdayMask & (1 << index)) !== 0
                                    foreground: Color.popups.text
                                    accent: Color.accent
                                    horizontalPadding: Style.space(4)
                                    verticalPadding: Style.space(2)
                                    onClicked: {
                                        if (selected)
                                            root.habitWeekdayMask &= ~(1 << index);
                                        else
                                            root.habitWeekdayMask |= 1 << index;
                                    }
                                }
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            text: "Lembretes · " + root.editingHabitReminderTimes.length
                            tooltipText: "Selecionar até 10 horários"
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            onClicked: root.habitReminderPickerVisible = true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            Button {
                                visible: root.editingHabitId !== ""
                                text: "Excluir"
                                foreground: Color.urgent
                                accent: Color.urgent
                                bordered: true
                                onClicked: root.deleteEditedHabit()
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Cancelar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.closeHabitEditor()
                            }
                            Button {
                                text: "Salvar"
                                enabled: habitTitleInput.text.trim() !== ""
                                         && root.habitWeekdayMask !== 0
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                onClicked: root.saveHabitEdit()
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 130
                visible: root.habitManualVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.habitManualVisible = false
                }

                BorderSurface {
                    id: habitManualCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(320))
                    height: contentTopInset + contentBottomInset + habitManualColumn.implicitHeight
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        id: habitManualColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: habitManualCard.contentLeftInset
                        anchors.rightMargin: habitManualCard.contentRightInset
                        spacing: Style.space(10)

                        Text {
                            text: "REGISTRAR PROGRESSO"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1
                        }
                        NumberField {
                            id: habitManualAmount
                            Layout.fillWidth: true
                            from: 1
                            to: 1000000000
                            value: 1
                            foreground: Color.popups.text
                            accent: Color.accent
                            onModified: updatedValue => value = updatedValue
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Cancelar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.habitManualVisible = false
                            }
                            Button {
                                id: habitManualRegister
                                focusable: true
                                text: "Registrar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                onClicked: root.recordManualHabit()
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 190
                visible: root.habitReminderPickerVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.habitReminderPickerVisible = false
                }

                BorderSurface {
                    id: habitReminderPickerCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(360))
                    height: contentTopInset + contentBottomInset + habitReminderPickerColumn.implicitHeight
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        id: habitReminderPickerColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: habitReminderPickerCard.contentLeftInset
                        anchors.rightMargin: habitReminderPickerCard.contentRightInset
                        spacing: Style.space(8)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "LEMBRETES"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                font.letterSpacing: 1
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.editingHabitReminderTimes.length + " / "
                                      + root.maximumHabitReminderCount
                                color: Qt.darker(Color.popups.text, 1.5)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                        }

                        Text {
                            visible: root.editingHabitReminderTimes.length === 0
                            text: "Nenhum horário adicionado."
                            color: Qt.darker(Color.popups.text, 1.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Repeater {
                            model: root.editingHabitReminderTimes

                            RowLayout {
                                required property string modelData
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: parent.modelData
                                    color: Color.popups.text
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                }
                                Button {
                                    text: "Remover"
                                    foreground: Color.urgent
                                    accent: Color.urgent
                                    bordered: true
                                    onClicked: root.removeHabitReminder(parent.modelData)
                                }
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            enabled: root.editingHabitReminderTimes.length
                                     < root.maximumHabitReminderCount
                            text: "+ Adicionar horário"
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            onClicked: root.openHabitReminderTimePicker()
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Concluir"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                onClicked: root.habitReminderPickerVisible = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 100
                visible: root.taskEditorVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeTaskEditor()
                }

                BorderSurface {
                    id: taskEditorCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(460))
                    height: Math.min(parent.height - Style.space(24),
                        contentTopInset + contentBottomInset + taskEditorColumn.implicitHeight)
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea {
                        anchors.fill: parent
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.topMargin: taskEditorCard.contentTopInset
                        anchors.bottomMargin: taskEditorCard.contentBottomInset
                        contentHeight: taskEditorColumn.implicitHeight
                        contentWidth: width
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        enabled: !root.creationPending
                        ScrollBar.vertical: ScrollBar {}
                    ColumnLayout {
                        id: taskEditorColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: taskEditorCard.contentLeftInset
                        anchors.rightMargin: taskEditorCard.contentRightInset
                        spacing: Style.space(10)

                        Text {
                            text: root.creatingTask ? "NOVA TAREFA · HORÁRIO" : "EDITAR TAREFA"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            Button {
                                visible: !root.creatingTask || root.taskMoreOptions
                                text: root.editingEmoji === "" ? "☺" : root.editingEmoji
                                tooltipText: "Escolher emoji"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                fontFamily: root.editingEmoji === ""
                                            ? root.fontFamily : "Noto Color Emoji"
                                onClicked: root.openEmojiPicker("edit", root.editingEmoji)
                            }

                            TextField {
                                id: taskTitleInput
                                Layout.fillWidth: true
                                text: ""
                                placeholderText: "Título"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selectByMouse: true
                                onAccepted: {
                                    if (root.creatingTask) {
                                        timePickerConfirm.forceActiveFocus();
                                    } else {
                                        root.openTimePicker(taskTimeInput, taskTimeInput.text);
                                    }
                                }
                            }
                        }

                        Button {
                            visible: root.creatingTask
                            Layout.fillWidth: true
                            text: root.portugueseLocale.toString(root.pendingQuickDate,
                                                                "ddd, dd 'de' MMMM 'de' yyyy")
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            tooltipText: "Alterar data"
                            onClicked: root.openTaskDatePicker(false)
                        }
                        TextField {
                            id: taskTimeInput
                            visible: false
                            text: ""
                            inputMethodHints: Qt.ImhTime
                            validator: RegularExpressionValidator {
                                regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
                            }
                        }

                        Button {
                            visible: !root.creatingTask
                            Layout.fillWidth: true
                            text: (taskTimeInput.acceptableInput
                                   ? taskTimeInput.text
                                   : "Selecionar horário") + "  ◷"
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            tooltipText: "Selecionar horário"
                            onClicked: root.openTimePicker(taskTimeInput, taskTimeInput.text)
                        }

                        Text {
                            visible: root.creatingTask
                            Layout.fillWidth: true
                            text: root.taskOptionsSummary()
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.Wrap
                        }
                        Button {
                            visible: root.creatingTask
                            Layout.fillWidth: true
                            text: root.taskMoreOptions ? "Menos opções" : "Mais opções"
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            onClicked: root.taskMoreOptions = !root.taskMoreOptions
                        }

                        Dropdown {
                            id: taskCategoryInput
                            visible: !root.creatingTask || root.taskMoreOptions
                            Layout.fillWidth: true
                            showLabel: false
                            foreground: Color.popups.text
                            background: Color.popups.background
                            accent: Color.accent
                            options: root.categoryOptions()
                            value: root.editingCategoryId
                            onChanged: function(value) {
                                root.editingCategoryId = String(value || "");
                            }
                        }

                        Button {
                            visible: !root.creatingTask || root.taskMoreOptions
                            Layout.fillWidth: true
                            text: "Notificações · " + root.editingReminderMinutesBefore.length
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            tooltipText: "Configurar até 5 notificações"
                            onClicked: root.reminderPickerVisible = true
                        }

                        Dropdown {
                            id: taskRecurrenceInput
                            visible: !root.creatingTask || root.taskMoreOptions
                            Layout.fillWidth: true
                            showLabel: false
                            foreground: Color.popups.text
                            background: Color.popups.background
                            accent: Color.accent
                            options: [
                                { label: "Não repetir", value: "none" },
                                { label: "Diariamente", value: "daily" },
                                { label: "Semanalmente", value: "weekly" },
                                { label: "Mensalmente", value: "monthly" },
                                { label: "Anualmente", value: "yearly" },
                                { label: "Personalizado", value: "custom" }
                            ]
                        }

                        GridLayout {
                            visible: (!root.creatingTask || root.taskMoreOptions)
                                     && taskRecurrenceInput.value === "custom"
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: Style.space(10)
                            rowSpacing: Style.space(8)

                            Text {
                                text: "Frequência"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            Dropdown {
                                id: taskCustomFrequency
                                Layout.fillWidth: true
                                showLabel: false
                                foreground: Color.popups.text
                                background: Color.popups.background
                                accent: Color.accent
                                options: [
                                    { label: "Diária", value: "daily" },
                                    { label: "Semanal", value: "weekly" },
                                    { label: "Mensal", value: "monthly" },
                                    { label: "Anual", value: "yearly" }
                                ]
                                onChanged: function(value) {
                                    if (value === "weekly" && root.editingWeekdayMask === 0)
                                        root.editingWeekdayMask = 1 << root.taskAnchorWeekdayIndex();
                                }
                            }

                            Text {
                                text: "A cada"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            RowLayout {
                                NumberField {
                                    id: taskCustomInterval
                                    from: 1
                                    to: 99
                                    value: 1
                                    foreground: Color.popups.text
                                    accent: Color.accent
                                }
                                Text {
                                    text: taskCustomFrequency.value === "daily" ? "dia(s)"
                                        : taskCustomFrequency.value === "weekly" ? "semana(s)"
                                        : taskCustomFrequency.value === "monthly" ? "mês(es)"
                                        : "ano(s)"
                                    color: Color.popups.text
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.caption
                                }
                            }

                            Text {
                                visible: taskCustomFrequency.value === "weekly"
                                text: "Somente em"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            RowLayout {
                                visible: taskCustomFrequency.value === "weekly"
                                spacing: Style.space(2)
                                Repeater {
                                    model: ["S", "T", "Q", "Q", "S", "S", "D"]
                                    Button {
                                        required property int index
                                        required property string modelData
                                        text: modelData
                                        selected: (root.editingWeekdayMask & (1 << index)) !== 0
                                        foreground: Color.popups.text
                                        accent: Color.accent
                                        horizontalPadding: Style.space(4)
                                        verticalPadding: Style.space(2)
                                        onClicked: {
                                            if (selected)
                                                root.editingWeekdayMask &= ~(1 << index);
                                            else
                                                root.editingWeekdayMask |= 1 << index;
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Termina"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            Dropdown {
                                id: taskCustomEnding
                                Layout.fillWidth: true
                                showLabel: false
                                foreground: Color.popups.text
                                background: Color.popups.background
                                accent: Color.accent
                                options: [
                                    { label: "Nunca", value: "never" },
                                    { label: "Em uma data", value: "onDate" },
                                    { label: "Após ocorrências", value: "afterCount" }
                                ]
                            }

                            Text {
                                visible: taskCustomEnding.value === "onDate"
                                text: "Data final"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            TextField {
                                id: taskCustomUntilDate
                                visible: false
                            }
                            Button {
                                visible: taskCustomEnding.value === "onDate"
                                Layout.fillWidth: true
                                text: root.portugueseLocale.toString(
                                    Model.parseLocalDate(taskCustomUntilDate.text), "dd/MM/yyyy")
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.openTaskDatePicker(true)
                            }

                            Text {
                                visible: taskCustomEnding.value === "afterCount"
                                text: "Ocorrências"
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                            NumberField {
                                id: taskCustomOccurrenceCount
                                visible: taskCustomEnding.value === "afterCount"
                                from: 1
                                to: 999
                                value: 10
                                foreground: Color.popups.text
                                accent: Color.accent
                            }
                        }

                        Item {
                            id: creationTimePickerSlot
                            visible: root.creatingTask
                            Layout.fillWidth: true
                            Layout.preferredHeight: timePickerColumn.implicitHeight
                        }

                        RowLayout {
                            visible: !root.creatingTask
                            Layout.fillWidth: true
                            Button {
                                text: root.editingCompleted ? "Alterar data da conclusão" : "Concluir"
                                visible: !root.editingSkipped
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                enabled: root.hostWidget && !root.hostWidget.actionBusy
                                onClicked: {
                                    root.closeTaskEditor();
                                    root.requestCompletion(root.editedTask, root.editingCompleted);
                                }
                            }
                            Button {
                                text: "Desfazer conclusão"
                                visible: root.editingCompleted
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                enabled: root.hostWidget && !root.hostWidget.actionBusy
                                onClicked: root.reopenEditedOccurrence()
                            }
                        }

                        RowLayout {
                            visible: !root.creatingTask
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            Button {
                                visible: !root.creatingTask
                                text: root.editingRecurringTask ? "Excluir série" : "Excluir tarefa"
                                foreground: Color.urgent
                                accent: Color.urgent
                                bordered: true
                                onClicked: root.deleteEditedTask()
                            }
                            Button {
                                visible: !root.creatingTask && root.editingRecurringTask
                                         && !root.editingCompleted && !root.editingSkipped
                                text: "Marcar não feita"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.skipEditedOccurrence()
                            }
                            Button {
                                visible: !root.creatingTask && root.editingSkipped
                                text: "Reabrir ocorrência"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.reopenEditedOccurrence()
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Button {
                                text: "Cancelar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.closeTaskEditor()
                            }
                            Button {
                                text: "Salvar"
                                focusable: true
                                enabled: taskTitleInput.text.trim() !== ""
                                         && taskTimeInput.acceptableInput
                                         && root.hostWidget && !root.hostWidget.actionBusy
                                         && !root.creationPending
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                onClicked: root.saveTaskEdit()
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.creatingTask && text !== ""
                            text: root.hostWidget ? root.hostWidget.actionError : ""
                            color: Color.urgent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.Wrap
                        }
                    }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 220
                visible: root.taskDatePickerVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.taskDatePickerVisible = false
                }
                BorderSurface {
                    id: taskDatePickerCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(400))
                    height: contentTopInset + contentBottomInset + taskDatePickerColumn.implicitHeight
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea { anchors.fill: parent }
                    ColumnLayout {
                        id: taskDatePickerColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: taskDatePickerCard.contentLeftInset
                        anchors.rightMargin: taskDatePickerCard.contentRightInset
                        spacing: Style.space(8)

                        Text {
                            text: root.taskDatePickerForEnding ? "DATA FINAL" : "DATA DA TAREFA"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                text: "‹"
                                tooltipText: "Mês anterior"
                                foreground: Color.popups.text
                                accent: Color.accent
                                onClicked: root.taskPickerMonth = new Date(
                                    root.taskPickerMonth.getFullYear(),
                                    root.taskPickerMonth.getMonth() - 1, 1)
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.portugueseLocale.toString(root.taskPickerMonth, "MMMM yyyy")
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                            }
                            Button {
                                text: "›"
                                tooltipText: "Próximo mês"
                                foreground: Color.popups.text
                                accent: Color.accent
                                onClicked: root.taskPickerMonth = new Date(
                                    root.taskPickerMonth.getFullYear(),
                                    root.taskPickerMonth.getMonth() + 1, 1)
                            }
                        }
                        DayOfWeekRow {
                            id: taskWeekdayRow
                            Layout.fillWidth: true
                            locale: root.portugueseLocale
                            delegate: Text {
                                required property var model
                                text: model.shortName
                                width: (taskWeekdayRow.availableWidth - 6 * taskWeekdayRow.spacing) / 7
                                horizontalAlignment: Text.AlignHCenter
                                color: Color.popups.text
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                            }
                        }
                        MonthGrid {
                            id: taskDateGrid
                            objectName: "waypointDraftCalendar"
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(210)
                            month: root.taskPickerMonth.getMonth()
                            year: root.taskPickerMonth.getFullYear()
                            locale: root.portugueseLocale
                            onClicked: date => root.chooseTaskDate(date)
                            delegate: Text {
                                required property var model
                                text: model.day
                                width: (taskDateGrid.availableWidth - 6 * taskDateGrid.spacing) / 7
                                height: (taskDateGrid.availableHeight - 5 * taskDateGrid.spacing) / 6
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: Model.dateKey(model.date) === (root.taskDatePickerForEnding
                                    ? taskCustomUntilDate.text : Model.dateKey(root.pendingQuickDate))
                                    ? Color.accent : Color.popups.text
                                opacity: model.month === taskDateGrid.month ? 1 : 0.4
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                font.bold: model.today
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                text: "Hoje"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.chooseTaskDate(new Date())
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Voltar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.taskDatePickerVisible = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 210
                visible: root.reminderPickerVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeReminderPicker()
                }

                BorderSurface {
                    id: reminderPickerCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(500))
                    height: contentTopInset + contentBottomInset
                            + reminderPickerColumn.implicitHeight
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        id: reminderPickerColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: reminderPickerCard.contentLeftInset
                        anchors.rightMargin: reminderPickerCard.contentRightInset
                        spacing: Style.space(8)

                        Text {
                            text: "NOTIFICAÇÕES · "
                                  + root.editingReminderMinutesBefore.length
                                  + "/" + root.maximumReminderCount
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                        }

                        Repeater {
                            model: [
                                { label: "No horário", minutes: 0 },
                                { label: "5 minutos antes", minutes: 5 },
                                { label: "30 minutos antes", minutes: 30 },
                                { label: "1 hora antes", minutes: 60 },
                                { label: "1 dia antes", minutes: 1440 }
                            ]

                            Button {
                                required property var modelData
                                Layout.fillWidth: true
                                text: (selected ? "✓  " : "")
                                      + String(modelData.label)
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                selected: root.containsEditingReminder(
                                              Number(modelData.minutes))
                                enabled: selected
                                         || root.editingReminderMinutesBefore.length
                                            < root.maximumReminderCount
                                onClicked: root.toggleEditingReminder(
                                               Number(modelData.minutes))
                            }
                        }

                        Text {
                            text: "PERSONALIZADO"
                            color: Color.popups.text
                            opacity: 0.7
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            NumberField {
                                id: reminderCustomAmount
                                from: 1
                                to: 999
                                value: 1
                                foreground: Color.popups.text
                                accent: Color.accent
                            }
                            Dropdown {
                                id: reminderCustomUnit
                                Layout.fillWidth: true
                                showLabel: false
                                foreground: Color.popups.text
                                background: Color.popups.background
                                accent: Color.accent
                                options: [
                                    { label: "minuto(s)", value: 1 },
                                    { label: "hora(s)", value: 60 },
                                    { label: "dia(s)", value: 1440 },
                                    { label: "semana(s)", value: 10080 }
                                ]
                            }
                            Button {
                                text: "Adicionar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                enabled: !root.containsEditingReminder(
                                             reminderCustomAmount.value
                                             * Number(reminderCustomUnit.value))
                                         && root.editingReminderMinutesBefore.length
                                            < root.maximumReminderCount
                                onClicked: root.addCustomReminder()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.editingReminderMinutesBefore.length > 0
                            text: root.editingReminderMinutesBefore.map(
                                      value => root.reminderLabel(value)).join(" · ")
                            color: Color.popups.text
                            opacity: 0.7
                            wrapMode: Text.Wrap
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.fillWidth: true
                            }
                            Button {
                                text: "Concluir"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                onClicked: root.closeReminderPicker()
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 200
                visible: root.timePickerVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeTimePicker()
                }

                BorderSurface {
                    id: timePickerCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(500))
                    height: contentTopInset + contentBottomInset + timePickerColumn.implicitHeight
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        id: timePickerColumn
                        readonly property bool embedded: root.creatingTask && root.taskEditorVisible
                        parent: embedded ? creationTimePickerSlot : timePickerCard
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: embedded ? 0 : timePickerCard.contentLeftInset
                        anchors.rightMargin: embedded ? 0 : timePickerCard.contentRightInset
                        spacing: Style.space(8)

                        Text {
                            text: "SELECIONAR HORÁRIO"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                        }

                        TextInput {
                            id: timePickerInput
                            objectName: "waypointDraftTime"
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            text: root.currentTimeKey()
                            color: Color.popups.text
                            selectionColor: Color.accent
                            selectedTextColor: Color.popups.text
                            horizontalAlignment: TextInput.AlignHCenter
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.display
                            font.bold: true
                            selectByMouse: true
                            inputMethodHints: Qt.ImhTime
                            validator: RegularExpressionValidator {
                                regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
                            }
                            onTextEdited: root.syncPickerSelectionFromText()
                            onAccepted: root.applyTimePicker()
                        }

                        Text {
                            text: "HORA"
                            color: Color.popups.text
                            opacity: 0.7
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: Style.space(4)
                            rowSpacing: Style.space(4)

                            Repeater {
                                model: 24

                                Button {
                                    required property int index
                                    Layout.fillWidth: true
                                    text: root.padTimePart(index)
                                    foreground: Color.popups.text
                                    accent: Color.accent
                                    selected: root.pickerHour === index
                                    horizontalPadding: Style.space(3)
                                    verticalPadding: Style.space(2)
                                    onClicked: root.choosePickerHour(index)
                                }
                            }
                        }

                        Text {
                            text: "MINUTO"
                            color: Color.popups.text
                            opacity: 0.7
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 10
                            columnSpacing: Style.space(3)
                            rowSpacing: Style.space(3)

                            Repeater {
                                model: 60

                                Button {
                                    required property int index
                                    Layout.fillWidth: true
                                    text: root.padTimePart(index)
                                    foreground: Color.popups.text
                                    accent: Color.accent
                                    selected: root.pickerMinute === index
                                    horizontalPadding: Style.space(3)
                                    verticalPadding: Style.space(2)
                                    onClicked: root.choosePickerMinute(index)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Style.space(4)
                            spacing: Style.space(8)

                            Button {
                                text: "Agora"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.selectCurrentPickerTime()
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Button {
                                text: "Cancelar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: {
                                    if (root.creatingTask && root.taskEditorVisible)
                                        root.closeTaskEditor();
                                    else
                                        root.closeTimePicker();
                                }
                            }
                            Button {
                                id: timePickerConfirm
                                objectName: "waypointDraftCreate"
                                text: timePickerColumn.embedded
                                      ? (root.creationPending ? "Criando…" : "Criar") : "Concluir"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                focusable: true
                                enabled: timePickerInput.acceptableInput
                                    && (!timePickerColumn.embedded
                                        || (taskTitleInput.text.trim() !== "" && root.hostWidget
                                            && !root.hostWidget.actionBusy && !root.creationPending))
                                onClicked: root.applyTimePicker()
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 230
                visible: root.completionPickerVisible
                color: Color.menu.scrim

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.completionPickerVisible = false
                }
                BorderSurface {
                    id: completionPickerCard
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(32), Style.space(440))
                    height: contentTopInset + contentBottomInset
                            + completionPickerColumn.implicitHeight
                    padding: Style.space(18)
                    radius: Style.cornerRadius
                    color: Color.popups.background
                    borderSpec: Border.localOrSurfaceSpec(
                        "popups", "border", Color.popups.border,
                        Color.popups.border, Style.normalBorderWidth)

                    MouseArea { anchors.fill: parent }
                    ColumnLayout {
                        id: completionPickerColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: completionPickerCard.contentLeftInset
                        anchors.rightMargin: completionPickerCard.contentRightInset
                        spacing: Style.space(10)

                        Text {
                            Layout.fillWidth: true
                            text: root.completionTask && root.completionTask.completed
                                  ? "Alterar data da conclusão" : "Quando foi concluída?"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.completionTask ? String(root.completionTask.title || "") : ""
                            color: Qt.darker(Color.popups.text, 1.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.Wrap
                        }
                        Button {
                            Layout.fillWidth: true
                            text: "Hoje"
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            enabled: root.hostWidget && !root.hostWidget.actionBusy
                            onClicked: root.saveCompletion(Model.dateKey(new Date()))
                        }
                        Button {
                            Layout.fillWidth: true
                            text: "Na data prevista"
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            enabled: root.completionTask
                                     && root.completionTask.occurrenceDate <= Model.dateKey(new Date())
                                     && root.hostWidget && !root.hostWidget.actionBusy
                            onClicked: root.saveCompletion(root.completionTask.occurrenceDate)
                        }
                        Button {
                            Layout.fillWidth: true
                            text: "Escolher data"
                            foreground: Color.popups.text
                            accent: Color.accent
                            bordered: true
                            onClicked: {
                                root.completionCustomDateVisible = true;
                                completionDateInput.forceActiveFocus();
                                completionDateInput.selectAll();
                            }
                        }
                        TextField {
                            id: completionDateInput
                            Layout.fillWidth: true
                            visible: root.completionCustomDateVisible
                            placeholderText: "AAAA-MM-DD"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            selectByMouse: true
                            validator: RegularExpressionValidator {
                                regularExpression: /\d{4}-\d{2}-\d{2}/
                            }
                            readonly property bool validDate: acceptableInput
                                && Qt.formatDate(Date.fromLocaleString(Qt.locale("C"), text,
                                                                      "yyyy-MM-dd"), "yyyy-MM-dd") === text
                                && text <= Model.dateKey(new Date())
                            onAccepted: {
                                if (validDate)
                                    root.saveCompletion(text);
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.completionCustomDateVisible
                            text: "Use AAAA-MM-DD, até hoje."
                            color: Qt.darker(Color.popups.text, 1.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                text: "Cancelar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                onClicked: root.completionPickerVisible = false
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                visible: root.completionCustomDateVisible
                                text: "Salvar"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                enabled: completionDateInput.validDate
                                         && root.hostWidget && !root.hostWidget.actionBusy
                                onClicked: root.saveCompletion(completionDateInput.text)
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                z: 240
                visible: root.completionFeedback !== "" && !root.completionPickerVisible
                height: completionFeedbackRow.implicitHeight + Style.space(16)
                color: Color.popups.background
                radius: Style.cornerRadius
                border.color: Color.accent
                border.width: Style.spacing.hairline

                RowLayout {
                    id: completionFeedbackRow
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    Text {
                        Layout.fillWidth: true
                        text: root.completionFeedback
                        color: Color.popups.text
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                    }
                    Button {
                        text: root.completionUndo
                              && root.completionUndo.previousCompletedDate === ""
                              ? "Reabrir tarefa" : "Desfazer"
                        visible: root.completionUndo !== null
                        foreground: Color.popups.text
                        accent: Color.accent
                        bordered: false
                        enabled: root.hostWidget && !root.hostWidget.actionBusy
                        onClicked: root.undoCompletion()
                    }
                    Button {
                        text: "Alterar data"
                        tooltipText: "Alterar data da conclusão"
                        visible: root.completionUndo !== null
                        foreground: Color.popups.text
                        accent: Color.accent
                        bordered: false
                        enabled: root.hostWidget && !root.hostWidget.actionBusy
                        onClicked: root.requestCompletion(root.completionUndo, true)
                    }
                }
            }

            EmojiPicker {
                id: emojiPicker
                anchors.fill: parent
                z: 220
                fontFamily: root.fontFamily
                onEmojiSelected: selectedEmoji => root.applyEmoji(selectedEmoji)
                onCancelled: root.emojiPickerTarget = ""
            }
        }
    }
}
