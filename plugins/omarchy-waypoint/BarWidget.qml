import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
    id: root
    moduleName: "io.waypoint.bar"

    property var tasks: []
    property string loadError: ""
    property var syncStatus: ({ state: "local-only", configured: false, lastError: "" })
    readonly property var summary: Model.todaySummary(tasks)
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

    function refresh() {
        if (!snapshotProcess.running)
            snapshotProcess.running = true;
    }

    function runAction(arguments) {
        if (actionProcess.running)
            return;
        actionProcess.command = ["waypointctl"].concat(arguments);
        actionProcess.running = true;
    }

    function addTask(title, date) {
        runAction(["add", "--date", Model.dateKey(date), "--title", title]);
    }

    function setTaskCompleted(taskId, completed) {
        runAction([completed ? "complete" : "reopen", taskId]);
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
        target.tasks = Qt.binding(() => root.tasks);
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

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const response = JSON.parse(String(text || "{}"));
                    if (!response.ok)
                        throw new Error(response.error || "snapshot failed");
                    root.tasks = response.tasks || [];
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
