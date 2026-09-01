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
    property var holidays: []
    property var holidaySyncStatus: ({ state: "local-only", lastError: "" })
    property string loadError: ""
    property var syncStatus: ({ state: "local-only", configured: false, lastError: "" })
    property date today: new Date()
    property date selectedDate: new Date()
    property int viewYear: selectedDate.getFullYear()
    property int viewMonth: selectedDate.getMonth()
    property bool taskEditorVisible: false
    property string editingTaskId: ""
    property bool timePickerVisible: false
    property var timePickerTarget: null
    property int pickerHour: 0
    property int pickerMinute: 0
    readonly property var pickerMinuteOptions: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
    property bool editingRecurringTask: false
    property var editingRecurrence: ({ frequency: "none", interval: 1, weekdays: [],
                                       endMode: "never", untilDate: "", occurrenceCount: 0 })
    property int editingWeekdayMask: 0

    readonly property var barIdentity: hostWidget || root
    readonly property var weeks: Model.monthWeeks(viewYear, viewMonth, occurrences, holidays)
    readonly property var selectedTasks: Model.occurrencesForDate(occurrences, selectedDate)
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


    function open() {
        today = new Date();
        selectedDate = today;
        viewYear = selectedDate.getFullYear();
        viewMonth = selectedDate.getMonth();
        if (hostWidget)
            hostWidget.refreshRange(viewYear, viewMonth);
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

    function openTimePicker(target) {
        timePickerTarget = target;
        if (target.acceptableInput) {
            const parts = target.text.split(":");
            pickerHour = Number(parts[0]);
            pickerMinute = Number(parts[1]);
        } else {
            const now = new Date();
            pickerHour = now.getHours();
            pickerMinute = now.getMinutes();
        }
        timePickerVisible = true;
    }

    function selectCurrentPickerTime() {
        const now = new Date();
        pickerHour = now.getHours();
        pickerMinute = now.getMinutes();
    }

    function closeTimePicker() {
        timePickerVisible = false;
        timePickerTarget = null;
    }

    function applyTimePicker() {
        if (timePickerTarget)
            timePickerTarget.text = padTimePart(pickerHour) + ":" + padTimePart(pickerMinute);
        closeTimePicker();
    }

    function submitQuickTask() {
        const title = quickAdd.text.trim();
        const time = quickAddTimeInput.text.trim();
        if (title === "" || !quickAddTimeInput.acceptableInput || !hostWidget)
            return;
        hostWidget.addTask(title, selectedDate, time);
        quickAdd.text = "";
        quickAddTimeInput.text = currentTimeKey();
        quickAdd.forceActiveFocus();
    }
    function taskAnchorWeekdayIndex() {
        return (selectedDate.getDay() + 6) % 7;
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

    function openTaskEditor(task) {
        editingTaskId = String(task.taskId || "");
        taskTitleInput.text = String(task.title || "");
        taskTimeInput.text = String(task.scheduledTime || "");
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
        taskCustomUntilDate.text = String(editingRecurrence.untilDate || Model.dateKey(selectedDate));
        taskCustomOccurrenceCount.value =
            Math.max(1, Number(editingRecurrence.occurrenceCount || 10));
        taskRecurrenceInput.value = taskRecurrencePresetValue();
        editingRecurringTask = task.recurring === true;
        taskEditorVisible = true;
        Qt.callLater(() => {
            taskTitleInput.forceActiveFocus();
            taskTitleInput.selectAll();
        });
    }

    function closeTaskEditor() {
        taskEditorVisible = false;
    }

    function saveTaskEdit() {
        const title = taskTitleInput.text.trim();
        const time = taskTimeInput.text.trim();
        if (title === "" || !taskTimeInput.acceptableInput || !hostWidget)
            return;
        const custom = taskRecurrenceInput.value === "custom";
        const frequency = custom ? taskCustomFrequency.value : taskRecurrenceInput.value;
        const endMode = custom ? taskCustomEnding.value : "never";
        const recurrence = {
            frequency: frequency,
            interval: custom ? taskCustomInterval.value : 1,
            weekdays: selectedTaskWeekdays(),
            endMode: endMode,
            untilDate: endMode === "onDate" ? taskCustomUntilDate.text.trim() : "",
            occurrenceCount: endMode === "afterCount" ? taskCustomOccurrenceCount.value : 0
        };
        hostWidget.editTask(editingTaskId, title, time, recurrence);
        closeTaskEditor();
    }
    function deleteEditedTask() {
        if (!hostWidget)
            return;
        hostWidget.deleteTask(editingTaskId);
        closeTaskEditor();
    }


    KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: true
        focusTarget: keyCatcher
        contentWidth: popup.fittedContentWidth(Style.space(560))
        contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onMoveRequested: function (dx, dy) {
                if (dx !== 0)
                    root.moveMonth(dx);
            }
            onActivateRequested: quickAdd.forceActiveFocus()
            onCloseRequested: root.close()

            Flickable {
                id: panelFlick
                anchors.fill: parent
                contentWidth: contentColumn.width
                contentHeight: contentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: contentColumn
                    width: Math.max(panelFlick.width, calendarGridColumn.width)
                    spacing: Style.space(8)

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
                                text: Qt.formatDate(root.selectedDate, "MMMM d")
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
                                    text: "W"
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
                                    model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

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


                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: Style.space(3)
                                                spacing: Style.space(2)

                                                Repeater {
                                                    model: Math.min(modelData.pending, 3)

                                                    Rectangle {
                                                        required property int index
                                                        width: Style.space(3)
                                                        height: width
                                                        radius: width / 2
                                                        color: index < modelData.overdue ? Color.urgent : Color.accent
                                                    }
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
                                text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy").toUpperCase()
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

                    Rectangle {
                        width: parent.width
                        height: Style.space(42)
                        radius: Style.cornerRadius
                        color: Style.hoverFillFor(root.foreground, Color.accent)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(4)

                            TextField {
                                id: quickAdd
                                Layout.fillWidth: true
                                placeholderText: "New task on " + Qt.formatDate(root.selectedDate, "MMM d") + "…"
                                color: root.foreground
                                placeholderTextColor: Qt.darker(root.foreground, 1.8)
                                font.family: root.fontFamily
                                background: Item {}
                                onAccepted: root.submitQuickTask()
                            }

                            TextField {
                                id: quickAddTimeInput
                                Layout.preferredWidth: Style.space(64)
                                text: root.currentTimeKey()
                                placeholderText: "HH:mm"
                                color: root.foreground
                                horizontalAlignment: TextInput.AlignHCenter
                                font.family: root.fontFamily
                                background: Item {}
                                inputMethodHints: Qt.ImhTime
                                validator: RegularExpressionValidator {
                                    regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
                                }
                                onAccepted: root.submitQuickTask()
                            }

                            Button {
                                text: "◷"
                                foreground: root.foreground
                                accent: Color.accent
                                bordered: true
                                horizontalPadding: Style.space(7)
                                verticalPadding: Style.space(3)
                                tooltipText: "Selecionar horário"
                                onClicked: root.openTimePicker(quickAddTimeInput)
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
                                required property var modelData
                                width: parent.width
                                height: Style.space(46)
                                radius: Style.cornerRadius
                                color: taskMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(50)
                                    spacing: Style.space(8)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.completed ? "󰄲" : "󰄱"
                                        color: modelData.completed ? Color.accent : root.foreground
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.body
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Style.space(40)
                                        spacing: 1

                                        Text {
                                            width: parent.width
                                            text: modelData.title
                                            color: modelData.completed ? Qt.darker(root.foreground, 1.8) : root.foreground
                                            elide: Text.ElideRight
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.body
                                            font.strikeout: modelData.completed
                                        }
                                        Text {
                                            width: parent.width
                                            text: {
                                                const time = String(modelData.scheduledTime || "");
                                                const recurrence = String(modelData.recurrenceLabel || "");
                                                return recurrence === "" ? time : time + " · " + recurrence;
                                            }
                                            color: Color.accent
                                            elide: Text.ElideRight
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
                                    onClicked: if (root.hostWidget)
                                        root.hostWidget.setOccurrenceCompleted(
                                            modelData.taskId, modelData.occurrenceDate,
                                            !modelData.completed)
                                }
                            }
                        }

                        Text {
                            visible: root.selectedTasks.length === 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.loadError !== "" ? root.loadError : "No tasks for this day"
                            color: root.loadError !== "" ? Color.urgent : Qt.darker(root.foreground, 1.9)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
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
                            text: root.syncStatus.state === "ready" ? "Synced"
                                : root.syncStatus.state === "syncing" ? "Syncing…"
                                : root.syncStatus.state === "error" ? "Sync error"
                                : "Local only"
                            color: Qt.darker(root.foreground, 1.5)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        PanelActionButton {
                            iconText: "󰒓"
                            tooltipText: "Waypoint settings"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            onClicked: if (root.hostWidget)
                                root.hostWidget.openSettings()
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
                    height: contentTopInset + contentBottomInset + taskEditorColumn.implicitHeight
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
                        id: taskEditorColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: taskEditorCard.contentLeftInset
                        anchors.rightMargin: taskEditorCard.contentRightInset
                        spacing: Style.space(10)

                        Text {
                            text: "EDITAR TAREFA"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        TextField {
                            id: taskTitleInput
                            Layout.fillWidth: true
                            text: ""
                            placeholderText: "Título"
                            foreground: Color.popups.text
                            accent: Color.accent
                            selectByMouse: true
                            onAccepted: taskTimeInput.forceActiveFocus()
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(4)

                            TextField {
                                id: taskTimeInput
                                Layout.fillWidth: true
                                text: ""
                                placeholderText: "HH:mm"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selectByMouse: true
                                inputMethodHints: Qt.ImhTime
                                validator: RegularExpressionValidator {
                                    regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
                                }
                                onAccepted: root.saveTaskEdit()
                            }

                            Button {
                                text: "◷"
                                foreground: Color.popups.text
                                accent: Color.accent
                                bordered: true
                                tooltipText: "Selecionar horário"
                                onClicked: root.openTimePicker(taskTimeInput)
                            }
                        }

                        Dropdown {
                            id: taskRecurrenceInput
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
                            visible: taskRecurrenceInput.value === "custom"
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
                                visible: taskCustomEnding.value === "onDate"
                                Layout.fillWidth: true
                                placeholderText: "AAAA-MM-DD"
                                foreground: Color.popups.text
                                accent: Color.accent
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            Button {
                                text: root.editingRecurringTask ? "Excluir série" : "Excluir tarefa"
                                foreground: Color.urgent
                                accent: Color.urgent
                                bordered: true
                                onClicked: root.deleteEditedTask()
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
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                onClicked: root.saveTaskEdit()
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
                    width: Math.min(parent.width - Style.space(32), Style.space(460))
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
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: timePickerCard.contentLeftInset
                        anchors.rightMargin: timePickerCard.contentRightInset
                        spacing: Style.space(8)

                        Text {
                            text: "SELECIONAR HORÁRIO"
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.subtitle
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.padTimePart(root.pickerHour) + ":"
                                + root.padTimePart(root.pickerMinute)
                            color: Color.popups.text
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.display
                            font.bold: true
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
                                    horizontalPadding: Style.space(5)
                                    verticalPadding: Style.space(3)
                                    onClicked: root.pickerHour = index
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
                            columns: 6
                            columnSpacing: Style.space(4)
                            rowSpacing: Style.space(4)

                            Repeater {
                                model: root.pickerMinuteOptions

                                Button {
                                    required property int index
                                    required property int modelData
                                    Layout.fillWidth: true
                                    text: root.padTimePart(modelData)
                                    foreground: Color.popups.text
                                    accent: Color.accent
                                    selected: root.pickerMinute === modelData
                                    horizontalPadding: Style.space(5)
                                    verticalPadding: Style.space(3)
                                    onClicked: root.pickerMinute = modelData
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
                                onClicked: root.closeTimePicker()
                            }
                            Button {
                                text: "Concluir"
                                foreground: Color.popups.text
                                accent: Color.accent
                                selected: true
                                onClicked: root.applyTimePicker()
                            }
                        }
                    }
                }
            }
        }
    }
}
