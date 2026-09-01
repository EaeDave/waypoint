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
    property var today: ({ pendingCount: 0, overdueCount: 0, occurrences: [] })
    property var holidays: []
    property var holidaySyncStatus: ({ state: "local-only", lastError: "" })
    property string loadError: ""
    property var syncStatus: ({ state: "local-only", configured: false, lastError: "" })
    property string rangeFrom: ""
    property string rangeTo: ""
    property bool refreshPending: false
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

    function addTask(title, date) {
        runAction(["add", "--date", Model.dateKey(date),
                   "--time", Qt.formatTime(new Date(), "HH:mm"),
                   "--title", title]);
    }

    function setOccurrenceCompleted(taskId, occurrenceDate, completed) {
        runAction([completed ? "complete" : "reopen", taskId,
                   "--date", occurrenceDate]);
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
        target.holidays = Qt.binding(() => root.holidays);
        target.holidaySyncStatus = Qt.binding(() => root.holidaySyncStatus);
        target.loadError = Qt.binding(() => root.loadError);
        target.syncStatus = Qt.binding(() => root.syncStatus);
    }

    function open() {
        refresh();
        if (panelLoader.item)
            panelLoader.item.open();
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
                    root.today = response.today || ({ pendingCount: 0, overdueCount: 0, occurrences: [] });
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
        text: root.vertical ? "󰄬" : "󰄬  " + root.summary.pending
        labelVisible: true
        hasVisualContent: true

        onPressed: function (mouseButton) {
            if (mouseButton === Qt.RightButton)
                root.openSettings();
            else
                root.toggle();
        }

        Component.onCompleted: {
            if (root.summary.overdue > 0)
                root.showTooltip(button, root.summary.overdue + " atrasada(s) · " + root.summary.pending + " hoje");
        }
    }
}
