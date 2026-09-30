pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    property string filter: "all"
    property var collapsedGroups: ({})
    CompletionActions {
        id: completionFlow
        controller: root.controller
    }
    function groupKey(listId) {
        return listId === "" ? "__entrada__" : listId;
    }
    function groupExpanded(listId) {
        return collapsedGroups[groupKey(listId)] !== true;
    }
    function toggleGroup(listId) {
        const key = groupKey(listId);
        const next = Object.assign({}, collapsedGroups);
        next[key] = groupExpanded(listId);
        collapsedGroups = next;
    }
    readonly property bool compact: width < WaypointTheme.compactBreakpoint
    readonly property var filteredTasks: {
        const query = searchField.text.trim().toLocaleLowerCase();
        const values = [];
        for (const task of controller.allTasks) {
            const recurring = task.recurring === true;
            if (filter === "recurring" && !recurring)
                continue;
            if (filter === "single" && recurring)
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

    TaskListManager {
        id: listManager
        controller: root.controller
        allowSelection: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 18 : 34
        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 4

                Text {
                    text: "Tarefas"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: root.compact ? WaypointTheme.displaySize
                                                 : WaypointTheme.displayLargeSize
                    font.bold: true
                }

                Text {
                    text: root.controller.allTasks.length + " tarefa"
                          + (root.controller.allTasks.length === 1 ? "" : "s")
                          + " existente" + (root.controller.allTasks.length === 1 ? "" : "s")
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
            }

            Item { Layout.fillWidth: true }

            AppButton {
                text: "+ Lista"
                selected: true
                onClicked: listManager.openForCreate()
            }

            AppTextField {
                id: searchField
                Layout.preferredWidth: root.compact ? 180 : 280
                placeholderText: "Buscar tarefas…"
            }
        }

        QuickTaskComposer {
            id: composer
            Layout.fillWidth: true
            Layout.topMargin: 24
            controller: root.controller
            scheduledDateKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
            contextualDate: false
            placeholderText: "Nova tarefa…"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 18
            Layout.bottomMargin: 10
            spacing: 8

            Text {
                text: "MOSTRAR"
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.bold: true
                font.letterSpacing: 1
            }

            AppButton {
                text: "Todas"
                selected: root.filter === "all"
                onClicked: root.filter = "all"
            }

            AppButton {
                text: "Recorrentes"
                selected: root.filter === "recurring"
                onClicked: root.filter = "recurring"
            }

            AppButton {
                text: "Únicas"
                selected: root.filter === "single"
                onClicked: root.filter = "single"
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
                spacing: 12

                Repeater {
                    model: root.taskGroups

                    ColumnLayout {
                        id: groupSection
                        required property var modelData
                        Layout.fillWidth: true
                        readonly property bool expanded:
                            root.groupExpanded(String(modelData.id || ""))
                        spacing: 2

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: WaypointTheme.radius
                            color: WaypointTheme.surface
                            border.width: 1
                            border.color: WaypointTheme.divider


                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 5
                                spacing: 8

                                Text {
                                    text: groupSection.expanded ? "▾" : "▸"
                                    color: WaypointTheme.subduedText
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.bodySize
                                }

                                Rectangle {
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 22
                                    radius: 3
                                    color: groupSection.modelData.color
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: groupSection.modelData.name.toUpperCase()
                                          + " · " + groupSection.modelData.tasks.length
                                    color: groupSection.modelData.id === ""
                                           ? WaypointTheme.foreground : groupSection.modelData.color
                                    font.family: WaypointTheme.fontFamily
                                    font.pixelSize: WaypointTheme.bodySmallSize
                                    font.bold: true
                                    font.letterSpacing: 0.8
                                }

                                AppButton {
                                    text: "+"
                                    square: true
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Criar tarefa em " + groupSection.modelData.name
                                    onClicked: composer.selectList(groupSection.modelData.id)
                                }

                                AppButton {
                                    visible: groupSection.modelData.id !== ""
                                    text: "…"
                                    square: true
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Editar ou excluir lista"
                                    onClicked: listManager.openForEdit(groupSection.modelData)
                                }
                            }
                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.rightMargin: groupSection.modelData.id === "" ? 54 : 98
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: (groupSection.expanded ? "Recolher " : "Expandir ")
                                                 + groupSection.modelData.name
                                Accessible.onPressAction:
                                    root.toggleGroup(String(groupSection.modelData.id || ""))
                                onClicked:
                                    root.toggleGroup(String(groupSection.modelData.id || ""))
                            }
                        }

                        Repeater {
                            model: groupSection.modelData.tasks

                            Item {
                                id: taskDelegate
                                required property var modelData
                                visible: groupSection.expanded
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible ? taskRow.implicitHeight : 0

                                TaskRow {
                                    id: taskRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
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
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.filteredTasks.length === 0
                    text: root.controller.allTasks.length === 0
                          ? "Crie sua primeira tarefa acima."
                          : "Nenhuma tarefa corresponde ao filtro."
                    color: WaypointTheme.disabledText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 24
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
