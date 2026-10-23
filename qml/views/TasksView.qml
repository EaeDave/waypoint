pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    // "" shows every list; "__entrada__" is the inbox; anything else is a category id.
    property string listFilter: ""
    property string searchQuery: ""
    property string filter: "all"
    property var collapsedGroups: ({})
    signal editListRequested(var list)

    CompletionActions {
        id: completionFlow
        controller: root.controller
    }
    function groupKey(listId) {
        return listId === "" ? "__entrada__" : listId;
    }
    function groupExpanded(listId) {
        return listFilter !== "" || collapsedGroups[groupKey(listId)] !== true;
    }
    function toggleGroup(listId) {
        const key = groupKey(listId);
        const next = Object.assign({}, collapsedGroups);
        next[key] = groupExpanded(listId);
        collapsedGroups = next;
    }
    readonly property bool compact: width < WaypointTheme.compactBreakpoint
    readonly property var activeList: {
        if (listFilter === "")
            return null;
        if (listFilter === "__entrada__")
            return { id: "", name: "Entrada", color: "" };
        for (const list of controller.taskCategories) {
            if (String(list.id || "") === listFilter)
                return list;
        }
        return null;
    }
    readonly property var filteredTasks: {
        const query = searchQuery.trim().toLocaleLowerCase();
        const values = [];
        for (const task of controller.allTasks) {
            const recurring = task.recurring === true;
            if (filter === "recurring" && !recurring)
                continue;
            if (filter === "single" && recurring)
                continue;
            if (listFilter !== "" && groupKey(String(task.categoryId || "")) !== listFilter)
                continue;
            const searchable = String(task.title || "") + " "
                             + String(task.categoryName || "");
            if (query !== "" && searchable.toLocaleLowerCase().indexOf(query) < 0)
                continue;
            values.push(task);
        }
        return values;
    }
    readonly property var taskGroups: {
        const groups = [];
        for (const list of controller.taskCategories) {
            const tasks = root.filteredTasks.filter(task =>
                String(task.categoryId || "") === String(list.id || ""));
            if (tasks.length > 0) {
                groups.push({
                    id: String(list.id || ""),
                    name: String(list.name || ""),
                    color: String(list.color || WaypointTheme.accent),
                    tasks: tasks
                });
            }
        }
        const inboxTasks = root.filteredTasks.filter(task =>
            String(task.categoryId || "") === "");
        if (inboxTasks.length > 0) {
            groups.push({
                id: "",
                name: "Entrada",
                color: WaypointTheme.subduedText,
                tasks: inboxTasks
            });
        }
        return groups;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 20 : 32
        anchors.rightMargin: root.compact ? 20 : 32
        anchors.topMargin: root.compact ? 20 : 28
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                spacing: 4

                RowLayout {
                    spacing: 10

                    Rectangle {
                        visible: root.activeList !== null && String(root.activeList.color || "") !== ""
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        radius: 5
                        color: root.activeList ? String(root.activeList.color || "transparent") : "transparent"
                    }

                    Text {
                        text: root.activeList ? String(root.activeList.name || "") : "Todas as tarefas"
                        color: WaypointTheme.foreground
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: root.compact ? WaypointTheme.displaySize
                                                     : WaypointTheme.displayLargeSize
                        font.weight: WaypointTheme.weightSemiBold
                    }
                }

                Text {
                    text: {
                        const count = root.listFilter === "" && root.searchQuery.trim() === ""
                                      ? root.controller.allTasks.length : root.filteredTasks.length;
                        let label = count + " tarefa" + (count === 1 ? "" : "s");
                        if (root.searchQuery.trim() !== "")
                            label += " · busca por “" + root.searchQuery.trim() + "”";
                        return label;
                    }
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
            }

            Item { Layout.fillWidth: true }

            AppButton {
                visible: root.activeList !== null && String(root.activeList.id || "") !== ""
                text: "Editar lista"
                flat: true
                onClicked: root.editListRequested(root.activeList)
            }
        }

        QuickTaskComposer {
            id: composer
            Layout.fillWidth: true
            Layout.topMargin: 20
            controller: root.controller
            scheduledDateKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
            contextualDate: false
            placeholderText: "Adicionar tarefa"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.bottomMargin: 12
            spacing: 4

            Repeater {
                model: [
                    { key: "all", label: "Todas" },
                    { key: "recurring", label: "Recorrentes" },
                    { key: "single", label: "Únicas" }
                ]

                AppButton {
                    required property var modelData
                    implicitHeight: 30
                    text: modelData.label
                    flat: true
                    selected: root.filter === modelData.key
                    onClicked: root.filter = modelData.key
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.filteredTasks.length + " exibida"
                      + (root.filteredTasks.length === 1 ? "" : "s")
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
            }
        }

        ScrollView {
            id: taskScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: taskScroll.availableWidth
                spacing: 16

                Repeater {
                    model: root.taskGroups

                    Rectangle {
                        id: groupSection
                        required property var modelData
                        readonly property bool expanded:
                            root.groupExpanded(String(modelData.id || ""))
                        Layout.fillWidth: true
                        Layout.preferredHeight: groupContent.implicitHeight
                        radius: WaypointTheme.radiusLarge
                        color: WaypointTheme.surface
                        border.width: 1
                        border.color: WaypointTheme.controlBorder

                        ColumnLayout {
                            id: groupContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 0

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.listFilter === ""
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    Accessible.role: Accessible.Button
                                    Accessible.name: (groupSection.expanded ? "Recolher " : "Expandir ")
                                                     + groupSection.modelData.name
                                    Accessible.onPressAction:
                                        root.toggleGroup(String(groupSection.modelData.id || ""))
                                    onClicked:
                                        root.toggleGroup(String(groupSection.modelData.id || ""))
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    AppIcon {
                                        visible: root.listFilter === ""
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        name: groupSection.expanded ? "chevron-down" : "chevron-right"
                                        color: WaypointTheme.subduedText
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 8
                                        Layout.preferredHeight: 8
                                        radius: 4
                                        color: groupSection.modelData.color
                                    }

                                    Text {
                                        text: groupSection.modelData.name
                                        color: WaypointTheme.foreground
                                        font.family: WaypointTheme.fontFamily
                                        font.pixelSize: WaypointTheme.bodySmallSize
                                        font.weight: WaypointTheme.weightSemiBold
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: groupSection.modelData.tasks.length
                                        color: WaypointTheme.disabledText
                                        font.family: WaypointTheme.fontFamily
                                        font.pixelSize: WaypointTheme.captionSize
                                        font.features: WaypointTheme.tabularNumbers
                                    }

                                    AppButton {
                                        flat: true
                                        square: true
                                        implicitHeight: 30
                                        Accessible.name: "Criar tarefa em " + groupSection.modelData.name
                                        ToolTip.visible: hovered
                                        ToolTip.text: Accessible.name
                                        onClicked: composer.selectList(groupSection.modelData.id)
                                        contentItem: Item {
                                            AppIcon {
                                                anchors.centerIn: parent
                                                width: 15
                                                height: 15
                                                name: "plus"
                                                color: WaypointTheme.subduedText
                                            }
                                        }
                                    }

                                    AppButton {
                                        visible: groupSection.modelData.id !== "" && root.listFilter === ""
                                        flat: true
                                        square: true
                                        implicitHeight: 30
                                        Accessible.name: "Editar ou excluir lista"
                                        ToolTip.visible: hovered
                                        ToolTip.text: Accessible.name
                                        onClicked: root.editListRequested(groupSection.modelData)
                                        contentItem: Item {
                                            AppIcon {
                                                anchors.centerIn: parent
                                                width: 16
                                                height: 16
                                                name: "more"
                                                color: WaypointTheme.subduedText
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: groupSection.expanded ? groupSection.modelData.tasks : []

                                Item {
                                    id: taskDelegate
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: taskRow.implicitHeight

                                    TaskRow {
                                        id: taskRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        showDivider: true
                                        taskId: taskDelegate.modelData.taskId
                                        title: taskDelegate.modelData.title
                                        scheduledDateKey: taskDelegate.modelData.scheduledDate
                                        pendingDate: taskDelegate.modelData.pendingDate || ""
                                        scheduledTimeKey: taskDelegate.modelData.scheduledTime
                                        emoji: taskDelegate.modelData.emoji || ""
                                        categoryId: taskDelegate.modelData.categoryId || ""
                                        categoryName: taskDelegate.modelData.categoryName || ""
                                        categoryColor: taskDelegate.modelData.categoryColor
                                                       || WaypointTheme.accent
                                        completed: taskDelegate.modelData.completed === true
                                        completedDate: taskDelegate.modelData.completedDate || ""
                                        registeredAt: taskDelegate.modelData.registeredAt || ""
                                        completionLabel: taskDelegate.modelData.completionLabel || ""
                                        completionLate: taskDelegate.modelData.completionLate === true
                                        skipped: false
                                        overdue: taskDelegate.modelData.overdue === true
                                        recurring: taskDelegate.modelData.recurring === true
                                        recurrenceLabel: taskDelegate.modelData.recurrenceLabel || ""
                                        recurrence: taskDelegate.modelData.recurrence || ({})
                                        reminderMinutesBefore:
                                            taskDelegate.modelData.reminderMinutesBefore || []
                                        controller: root.controller
                                        completionActions: completionFlow
                                        definitionMode: true
                                    }
                                }
                            }

                            Item {
                                visible: groupSection.expanded
                                Layout.preferredHeight: 4
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    visible: root.filteredTasks.length === 0
                    text: root.controller.allTasks.length === 0
                          ? "Crie sua primeira tarefa acima."
                          : "Nenhuma tarefa corresponde ao filtro."
                    color: WaypointTheme.disabledText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.preferredHeight: 12 }
            }
        }
    }

    Shortcut {
        sequence: "N"
        onActivated: composer.focusInput()
    }
}
