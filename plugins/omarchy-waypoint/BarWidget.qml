import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
    id: root
    moduleName: "io.waypoint.bar"

    property var occurrences: []
    property var today: ({ pendingCount: 0, overdueCount: 0, occurrences: [], habits: [] })
    property var holidays: []
    property var holidaySyncStatus: ({ state: "local-only", lastError: "" })
    property string loadError: ""
    property var syncStatus: ({ state: "local-only", configured: false, lastError: "" })
    property string rangeFrom: ""
    property string rangeTo: ""
    property bool refreshPending: false
    property date displayDate: clock.date
    readonly property string clockFormat: root.vertical
        ? root.setting("verticalFormat", "HH\n—\nmm")
        : root.setting("format", "yyyy-MM-dd HH:mm")
    readonly property string clockText: Qt.formatDateTime(root.displayDate, root.clockFormat)
    readonly property var verticalLines: root.clockText.split("\n").concat(["󰄬 " + root.summary.pending])
    readonly property var summary: Model.todaySummary(today)
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

    function refresh() {
        if (snapshotProcess.running) {
            refreshPending = true;
            return;
        }
        const command = ["waypointctl", "snapshot"];
        if (rangeFrom !== "" && rangeTo !== "")
            command.push("--from", rangeFrom, "--to", rangeTo);
        snapshotProcess.command = command;
        snapshotProcess.running = true;
    }

    function refreshRange(year, month) {
        const range = Model.monthRange(year, month);
        rangeFrom = range.from;
        rangeTo = range.to;
        refresh();
    }

    function runAction(arguments) {
        if (actionProcess.running)
            return;
        actionProcess.command = ["waypointctl"].concat(arguments);
        actionProcess.running = true;
    }

    function addTask(title, date, scheduledTime, reminderMinutesBefore, emoji) {
        const time = scheduledTime || Qt.formatTime(new Date(), "HH:mm");
        const reminders = reminderMinutesBefore.length === 0
            ? "none" : reminderMinutesBefore.join(",");
        runAction(["add", "--date", Model.dateKey(date),
                   "--time", time, "--reminders", reminders,
                   "--title", title, "--emoji", emoji || ""]);
    }

    function setOccurrenceCompleted(taskId, occurrenceDate, completed) {
        runAction([completed ? "complete" : "reopen", taskId,
                   "--date", occurrenceDate]);
    }
    function skipOccurrence(taskId, occurrenceDate) {
        runAction(["skip", taskId, "--date", occurrenceDate]);
    }
    function editTask(taskId, title, scheduledTime, recurrence,
                      reminderMinutesBefore, emoji) {
        const reminders = reminderMinutesBefore.length === 0
            ? "none" : reminderMinutesBefore.join(",");
        const arguments = ["edit", taskId, "--title", title, "--time", scheduledTime,
                           "--reminders", reminders, "--emoji", emoji || "",
                           "--frequency", recurrence.frequency || "none",
                           "--interval", String(recurrence.interval || 1),
                           "--end-mode", recurrence.endMode || "never",
                           "--count", String(recurrence.occurrenceCount || 0)];
        const weekdays = (recurrence.weekdays || []).join(",");
        if (weekdays !== "")
            arguments.push("--weekdays", weekdays);
        if (recurrence.untilDate)
            arguments.push("--until", recurrence.untilDate);
        runAction(arguments);
    }

    function deleteTask(taskId) {
        runAction(["delete", taskId]);
    }

    function saveHabit(habit) {
        const reminders = habit.reminderTimes.length === 0
            ? "none" : habit.reminderTimes.join(",");
        const arguments = [habit.id === "" ? "add-habit" : "edit-habit"];
        if (habit.id !== "")
            arguments.push(habit.id);
        arguments.push("--title", habit.title,
                       "--goal", String(habit.targetAmount),
                       "--unit", habit.unit || "",
                       "--check-in", habit.checkInMode,
                       "--increment", String(habit.incrementAmount),
                       "--weekdays", habit.weekdays.join(","),
                       "--reminder-times", reminders,
                       "--emoji", habit.emoji || "");
        runAction(arguments);
    }

    function recordHabit(habitId, amount) {
        const arguments = ["record-habit", habitId];
        if (amount > 0)
            arguments.push("--amount", String(amount));
        runAction(arguments);
    }

    function undoHabit(habitId) {
        runAction(["undo-habit", habitId]);
    }

    function deleteHabit(habitId) {
        runAction(["delete-habit", habitId]);
    }


    function openSettings() {
        if (!settingsProcess.running) {
            settingsProcess.running = true;
            close();
        }
    }

    function injectPanel() {
        const target = panelLoader.item;
        if (!target)
            return;
        target.bar = root.bar;
        target.anchorItem = button;
        target.hostWidget = root;
        target.occurrences = Qt.binding(() => root.occurrences);
        target.today = Qt.binding(() => new Date(Model.parseLocalDate(root.today.date)));
        target.todayTasks = Qt.binding(() => root.today.occurrences || []);
        target.todayHabits = Qt.binding(() => root.today.habits || []);
        target.holidays = Qt.binding(() => root.holidays);
        target.holidaySyncStatus = Qt.binding(() => root.holidaySyncStatus);
        target.loadError = Qt.binding(() => root.loadError);
        target.syncStatus = Qt.binding(() => root.syncStatus);
    }

    function open() {
        if (panelLoader.item)
            panelLoader.item.open();
        else
            refresh();
    }

    function close() {
        if (panelLoader.item)
            panelLoader.item.close();
    }

    function toggle() {
        if (opened)
            close();
        else
            open();
    }

    function closeForPopoutSwitch() {
        close();
    }

    onBarChanged: injectPanel()

    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    readonly property real openPanelIndicatorWidth: button.labelWidth
    readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: root.displayDate = date
    }

    IpcHandler {
        target: "io.waypoint.bar"

        function refresh(): void { root.broadcast("refresh"); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function show(): void { root.open(); }
        function hide(): void { root.close(); }
        function toggle(): void { root.toggle(); }
    }

    Process {
        id: snapshotProcess
        command: ["waypointctl", "snapshot"]
        running: true

        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                root.refresh();
            }
        }
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const response = JSON.parse(String(text || "{}"));
                    if (!response.ok)
                        throw new Error(response.error || "snapshot failed");
                    root.today = response.today || ({ pendingCount: 0, overdueCount: 0,
                                                       occurrences: [], habits: [] });
                    root.occurrences = response.occurrences || [];
                    root.holidays = response.holidays || [];
                    root.holidaySyncStatus = response.holidaySync || ({ state: "local-only", lastError: "" });
                    root.loadError = "";
                    root.syncStatus = response.sync || ({ state: "local-only", configured: false, lastError: "" });
                } catch (error) {
                    root.loadError = String(error);
                }
            }
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const message = String(text || "").trim();
                if (message !== "")
                    root.loadError = message;
            }
        }
    }

    Process {
        id: actionProcess
        running: false
        onExited: root.refresh()
    }

    Process {
        id: settingsProcess
        command: ["waypoint", "--settings"]
        running: false
    }

    Timer {
        interval: root.opened ? 2000 : 15000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel();
            Qt.callLater(root.injectPanel);
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.vertical ? "" : root.clockText + "  ·  󰄬 " + root.summary.pending
        labelVisible: !root.vertical
        hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
        fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
        horizontalMargin: 8.75
        verticalPadding: 8.75

        onPressed: function (mouseButton) {
            if (mouseButton === Qt.RightButton)
                root.openSettings();
            else if (mouseButton === Qt.MiddleButton) {
                if (root.bar)
                    root.bar.run("omarchy-menu-timezone");
            } else {
                root.toggle();
            }
        }

        Column {
            visible: root.vertical
            anchors.fill: parent

            Repeater {
                model: root.verticalLines

                OpticalGlyph {
                    required property string modelData
                    width: button.width
                    height: Style.bar.iconSlot
                    text: modelData
                    fontFamily: button.fontFamily
                    fontSize: modelData.length > 5
                        ? button.fontSize * 0.85
                        : button.fontSize
                    color: button.foreground
                }
            }
        }

        Component.onCompleted: {
            if (root.summary.overdue > 0)
                root.showTooltip(button, root.summary.overdue + " atrasada(s) · " + root.summary.pending + " hoje");
        }
    }
}
