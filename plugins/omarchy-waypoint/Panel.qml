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
    property var tasks: []
    property string loadError: ""
    property var syncStatus: ({ state: "local-only", configured: false, lastError: "" })
    property date selectedDate: new Date()
    property int viewYear: selectedDate.getFullYear()
    property int viewMonth: selectedDate.getMonth()

    readonly property var barIdentity: hostWidget || root
    readonly property var cells: Model.monthCells(viewYear, viewMonth, tasks)
    readonly property var selectedTasks: Model.tasksForDate(tasks, selectedDate)
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

    function open() {
        selectedDate = new Date();
        viewYear = selectedDate.getFullYear();
        viewMonth = selectedDate.getMonth();
        if (hostWidget)
            hostWidget.refresh();
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
    }

    function selectDay(date) {
        selectedDate = date;
        if (date.getMonth() !== viewMonth || date.getFullYear() !== viewYear) {
            viewMonth = date.getMonth();
            viewYear = date.getFullYear();
        }
        Qt.callLater(() => quickAdd.forceActiveFocus());
    }

    KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: false
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
                anchors.fill: parent
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: Style.space(10)

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Style.space(12)

                        Text {
                            text: "󰃭"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.title
                        }

                        Text {
                            text: Qt.formatDate(root.selectedDate, "MMMM d")
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.hero
                            font.bold: true
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.spacing.hairline
                        color: Qt.darker(root.foreground, 2.6)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Style.space(4)

                        Item {
                            width: Style.space(26)
                            height: Style.space(16)
                        }

                        Repeater {
                            model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                            Text {
                                required property string modelData
                                width: Style.space(52)
                                height: Style.space(16)
                                text: modelData
                                color: Qt.darker(root.foreground, 1.7)
                                horizontalAlignment: Text.AlignHCenter
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                font.letterSpacing: 1
                            }
                        }
                    }

                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 7
                        columnSpacing: Style.space(4)
                        rowSpacing: Style.space(3)

                        Repeater {
                            model: root.cells

                            Rectangle {
                                required property var modelData
                                width: Style.space(52)
                                height: Style.space(38)
                                radius: Style.cornerRadius
                                color: cellMouse.containsMouse || Model.dateKey(root.selectedDate) === modelData.key ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                                border.width: modelData.today ? Style.spacing.hairline : 0
                                border.color: Style.normalBorderFor(root.foreground, Color.accent)

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -2
                                    text: modelData.day
                                    color: modelData.inMonth ? (modelData.weekend ? Qt.darker(root.foreground, 1.45) : root.foreground) : Qt.darker(root.foreground, 2.2)
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.body
                                    font.bold: modelData.today
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: Style.space(4)
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
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectDay(modelData.date)
                                }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width

                        ToolButton {
                            text: "‹"
                            onClicked: root.moveMonth(-1)
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy").toUpperCase()
                            color: Qt.darker(root.foreground, 1.25)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.letterSpacing: 1
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        ToolButton {
                            text: "›"
                            onClicked: root.moveMonth(1)
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.space(42)
                        radius: Style.cornerRadius
                        color: Style.hoverFillFor(root.foreground, Color.accent)

                        TextField {
                            id: quickAdd
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            placeholderText: "New task on " + Qt.formatDate(root.selectedDate, "MMM d") + "…"
                            color: root.foreground
                            placeholderTextColor: Qt.darker(root.foreground, 1.8)
                            font.family: root.fontFamily
                            background: Item {}
                            onAccepted: {
                                const title = text.trim();
                                if (title === "" || !root.hostWidget)
                                    return;
                                root.hostWidget.addTask(title, root.selectedDate);
                                text = "";
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
                                height: Style.space(36)
                                radius: Style.cornerRadius
                                color: taskMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(8)
                                    spacing: Style.space(8)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.completed ? "󰄲" : "󰄱"
                                        color: modelData.completed ? Color.accent : root.foreground
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.body
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Style.space(40)
                                        text: modelData.title
                                        color: modelData.completed ? Qt.darker(root.foreground, 1.8) : root.foreground
                                        elide: Text.ElideRight
                                        font.family: root.fontFamily
                                        font.pixelSize: Style.font.body
                                        font.strikeout: modelData.completed
                                    }
                                }

                                MouseArea {
                                    id: taskMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.hostWidget)
                                        root.hostWidget.setTaskCompleted(modelData.id, !modelData.completed)
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

                        ToolButton {
                            text: "Settings"
                            onClicked: if (root.hostWidget)
                                root.hostWidget.openSettings()
                        }
                    }
                }
            }
        }
    }
}
