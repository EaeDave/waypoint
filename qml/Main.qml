pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "views"
import "components"

ApplicationWindow {
    id: root

    required property var waypointController

    width: 1200
    height: 780
    minimumWidth: 600
    minimumHeight: 520
    visible: true
    title: "Waypoint"
    color: WaypointTheme.background
    font.family: WaypointTheme.fontFamily
    font.pixelSize: WaypointTheme.bodySize

    palette.window: WaypointTheme.background
    palette.windowText: WaypointTheme.foreground
    palette.base: WaypointTheme.background
    palette.alternateBase: WaypointTheme.controlFill
    palette.text: WaypointTheme.foreground
    palette.button: WaypointTheme.controlFill
    palette.buttonText: WaypointTheme.foreground
    palette.highlight: WaypointTheme.accentSoft
    palette.highlightedText: WaypointTheme.foreground
    palette.mid: WaypointTheme.controlBorder
    palette.toolTipBase: WaypointTheme.popupFill
    palette.toolTipText: WaypointTheme.foreground

    readonly property var pages: ["today", "tasks", "calendar", "settings"]
    property string activePage: "today"
    // "" shows every list; "__entrada__" is the inbox; anything else is a category id.
    property string listFilter: ""
    property bool sidebarPinnedCollapsed: false
    readonly property bool sidebarCollapsed: sidebarPinnedCollapsed || width < 860
    property date now: new Date()

    readonly property var listCounts: {
        const counts = ({});
        for (const task of waypointController.allTasks) {
            const key = String(task.categoryId || "") || "__entrada__";
            counts[key] = (counts[key] || 0) + 1;
        }
        return counts;
    }

    function openPage(page) {
        if (pages.indexOf(page) < 0)
            return;
        if (page === "tasks")
            listFilter = "";
        activePage = page;
    }

    function openList(key) {
        listFilter = key;
        activePage = "tasks";
    }

    function syncLabel() {
        if (!waypointController.online)
            return "Daemon desconectado";
        if (waypointController.syncState === "syncing")
            return "Sincronizando";
        if (waypointController.syncState === "ready")
            return "Sincronizado";
        if (waypointController.syncState === "error")
            return "Erro de sincronização";
        return "Somente local";
    }

    function syncColor() {
        if (!waypointController.online || waypointController.syncState === "error")
            return WaypointTheme.urgent;
        if (waypointController.syncState === "ready")
            return WaypointTheme.success;
        if (waypointController.syncState === "syncing")
            return WaypointTheme.accent;
        return WaypointTheme.subduedText;
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    TaskListManager {
        id: listManager
        controller: root.waypointController
        allowSelection: false
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: sidebar
            Layout.preferredWidth: root.sidebarCollapsed ? 60 : 236
            Layout.fillHeight: true
            color: WaypointTheme.sidebar
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.sidebarCollapsed ? 10 : 12
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    Layout.bottomMargin: 14
                    spacing: 10

                    AbstractButton {
                        id: logo
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.leftMargin: root.sidebarCollapsed ? 0 : 4
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: root.sidebarCollapsed
                        hoverEnabled: true
                        enabled: root.sidebarPinnedCollapsed && root.width >= 860
                        Accessible.name: "Expandir barra lateral"
                        ToolTip.visible: enabled && hovered
                        ToolTip.text: Accessible.name
                        onClicked: root.sidebarPinnedCollapsed = false
                        background: null

                        contentItem: Item {
                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: WaypointTheme.radius
                                color: logo.hovered && logo.enabled ? Qt.lighter(WaypointTheme.accent, 1.08)
                                                                    : WaypointTheme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "W"
                                    color: WaypointTheme.background
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.titleSize
                                    font.weight: WaypointTheme.weightSemiBold
                                }
                            }
                        }
                    }

                    Text {
                        visible: !root.sidebarCollapsed
                        Layout.fillWidth: true
                        text: "Waypoint"
                        color: WaypointTheme.foreground
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.titleSize
                        font.weight: WaypointTheme.weightSemiBold
                    }

                    AppButton {
                        visible: !root.sidebarCollapsed && root.width >= 860
                        flat: true
                        square: true
                        implicitHeight: 30
                        Accessible.name: "Recolher barra lateral"
                        ToolTip.visible: hovered
                        ToolTip.text: Accessible.name
                        onClicked: root.sidebarPinnedCollapsed = true
                        contentItem: Item {
                            AppIcon {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                name: "sidebar"
                                color: WaypointTheme.subduedText
                            }
                        }
                    }
                }

                Text {
                    visible: !root.sidebarCollapsed
                    Layout.leftMargin: 10
                    Layout.bottomMargin: 4
                    text: "Visões"
                    color: WaypointTheme.disabledText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.captionSize
                    font.weight: WaypointTheme.weightMedium
                }

                NavItem {
                    Layout.fillWidth: true
                    text: "Hoje"
                    iconName: "tasks"
                    count: root.waypointController.todayTasks.pendingCount
                    collapsed: root.sidebarCollapsed
                    selected: root.activePage === "today"
                    onClicked: root.openPage("today")
                }

                NavItem {
                    Layout.fillWidth: true
                    text: "Todas as tarefas"
                    iconName: "list"
                    count: root.waypointController.allTasks.length
                    collapsed: root.sidebarCollapsed
                    selected: root.activePage === "tasks" && root.listFilter === ""
                    onClicked: root.openPage("tasks")
                }

                NavItem {
                    Layout.fillWidth: true
                    text: "Calendário"
                    iconName: "calendar"
                    collapsed: root.sidebarCollapsed
                    selected: root.activePage === "calendar"
                    onClicked: root.openPage("calendar")
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    Layout.leftMargin: root.sidebarCollapsed ? 6 : 10
                    Layout.rightMargin: root.sidebarCollapsed ? 6 : 10
                    color: WaypointTheme.divider
                }

                RowLayout {
                    visible: !root.sidebarCollapsed
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.bottomMargin: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Listas"
                        color: WaypointTheme.disabledText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.captionSize
                        font.weight: WaypointTheme.weightMedium
                    }

                    AppButton {
                        flat: true
                        square: true
                        implicitHeight: 24
                        Accessible.name: "Nova lista"
                        ToolTip.visible: hovered
                        ToolTip.text: Accessible.name
                        onClicked: listManager.openForCreate()
                        contentItem: Item {
                            AppIcon {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                name: "plus"
                                color: WaypointTheme.subduedText
                            }
                        }
                    }
                }

                ListView {
                    id: listNavigation
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: [{ id: "__entrada__", name: "Entrada", color: "" }]
                           .concat(root.waypointController.taskCategories)
                    ScrollIndicator.vertical: ScrollIndicator {}

                    delegate: NavItem {
                        required property var modelData
                        readonly property string key: String(modelData.id || "")
                        width: listNavigation.width
                        text: String(modelData.name || "")
                        iconName: key === "__entrada__" ? "inbox" : ""
                        dotColor: String(modelData.color || WaypointTheme.subduedText)
                        count: root.listCounts[key] || 0
                        collapsed: root.sidebarCollapsed
                        selected: root.activePage === "tasks" && root.listFilter === key
                        onClicked: root.openList(key)
                    }
                }

                NavItem {
                    Layout.fillWidth: true
                    text: "Configurações"
                    iconName: "settings"
                    collapsed: root.sidebarCollapsed
                    selected: root.activePage === "settings"
                    onClicked: root.openPage("settings")
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: WaypointTheme.divider
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: clockRow.implicitWidth + 22
                    Layout.preferredHeight: 30
                    radius: WaypointTheme.radius
                    color: "transparent"
                    border.width: 1
                    border.color: WaypointTheme.controlBorder

                    RowLayout {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 8

                        AppIcon {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            name: "clock"
                            color: WaypointTheme.subduedText
                        }

                        Text {
                            text: Qt.formatTime(root.now, "HH:mm")
                            color: WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySmallSize
                            font.weight: WaypointTheme.weightMedium
                            font.features: WaypointTheme.tabularNumbers
                        }

                        Text {
                            text: Qt.locale("pt_BR").toString(root.now, "ddd, d MMM")
                            color: WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySmallSize
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                AppTextField {
                    id: searchField
                    Layout.preferredWidth: root.width < 900 ? 200 : 280
                    implicitHeight: 32
                    leftPadding: 34
                    rightPadding: shortcutHint.visible ? 58 : 12
                    placeholderText: "Buscar tarefas…"
                    Accessible.name: "Buscar tarefas"
                    onTextEdited: {
                        if (text.trim() !== "" && root.activePage !== "tasks")
                            root.activePage = "tasks";
                    }
                    Keys.onEscapePressed: {
                        clear();
                        focus = false;
                    }

                    AppIcon {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15
                        height: 15
                        name: "search"
                        color: WaypointTheme.disabledText
                    }

                    Rectangle {
                        id: shortcutHint
                        visible: searchField.text === "" && !searchField.activeFocus
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        width: hintText.implicitWidth + 12
                        height: 20
                        radius: 5
                        color: "transparent"
                        border.width: 1
                        border.color: WaypointTheme.controlBorder

                        Text {
                            id: hintText
                            anchors.centerIn: parent
                            text: "Ctrl K"
                            color: WaypointTheme.disabledText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                AbstractButton {
                    id: syncStatus
                    Layout.preferredHeight: 30
                    hoverEnabled: true
                    leftPadding: 8
                    rightPadding: 8
                    Accessible.name: "Status: " + root.syncLabel()
                    ToolTip.visible: hovered && ToolTip.text !== ""
                    ToolTip.text: !root.waypointController.online ? root.waypointController.errorMessage
                                : root.waypointController.syncState === "error"
                                  ? root.waypointController.syncLastError : ""
                    onClicked: root.openPage("settings")

                    contentItem: RowLayout {
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            radius: 4
                            color: root.syncColor()
                        }

                        Text {
                            visible: root.width >= 760
                            text: root.syncLabel()
                            color: WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySmallSize
                        }
                    }

                    background: Rectangle {
                        radius: WaypointTheme.radius
                        color: syncStatus.hovered ? WaypointTheme.controlHoverFill : "transparent"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: WaypointTheme.divider
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: Math.max(0, root.pages.indexOf(root.activePage))

                TodayView {
                    controller: root.waypointController
                }

                TasksView {
                    controller: root.waypointController
                    listFilter: root.listFilter
                    searchQuery: searchField.text
                    onEditListRequested: list => listManager.openForEdit(list)
                }

                MonthView {
                    controller: root.waypointController
                }

                SettingsView {
                    controller: root.waypointController
                }
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+1"
        onActivated: root.openPage("today")
    }

    Shortcut {
        sequence: "Ctrl+2"
        onActivated: root.openPage("tasks")
    }

    Shortcut {
        sequence: "Ctrl+3"
        onActivated: root.openPage("calendar")
    }

    Shortcut {
        sequence: "Ctrl+4"
        onActivated: root.openPage("settings")
    }

    Shortcut {
        sequences: ["Ctrl+K", StandardKey.Find]
        onActivated: {
            searchField.forceActiveFocus();
            searchField.selectAll();
        }
    }

    Component.onCompleted: root.waypointController.start()
}
