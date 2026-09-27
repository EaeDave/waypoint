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
    readonly property var portugueseLocale: Qt.locale("pt_BR")
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
                    color: String(list.color || MobileTheme.accent),
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
                color: MobileTheme.subdued,
                tasks: inboxTasks
            });
        }
        return groups;
    }

    function openTask(taskId) {
        for (const task of controller.allTasks) {
            if (task.taskId === taskId) {
                taskEditor.openForEdit(task);
                return true;
            }
        }
        return false;
    }

    function createTask(listId) {
        taskEditor.openForCreate(controller.todayKey, listId || "");
    }

    TaskEditor {
        id: taskEditor
        controller: root.controller
    }

    TaskListManager {
        id: listManager
        controller: root.controller
        onListSelected: function(listId) {
            root.createTask(listId);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: MobileTheme.pageMargin
        anchors.rightMargin: MobileTheme.pageMargin
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 18

            ColumnLayout {
                spacing: 3

                Text {
                    text: "Tarefas"
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.displaySize
                    font.bold: true
                }

                Text {
                    text: root.controller.allTasks.length + " existente"
                          + (root.controller.allTasks.length === 1 ? "" : "s")
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySmallSize
                }
            }

            Item { Layout.fillWidth: true }

            MobileButton {
                Layout.preferredWidth: 82
                text: "+ LISTA"
                quiet: true
                Accessible.id: "tasks-create-list"
                onClicked: listManager.openForCreate()
            }

            MobileButton {
                Layout.preferredWidth: 104
                text: "+ TAREFA"
                accent: true
                Accessible.id: "tasks-create-task"
                onClicked: root.createTask("")
            }
        }

        MobileField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: "Buscar tarefas"
            Accessible.id: "tasks-search"
            Accessible.name: "Buscar tarefas"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MobileButton {
                Layout.fillWidth: true
                text: "TODAS"
                accent: root.filter === "all"
                quiet: root.filter !== "all"
                onClicked: root.filter = "all"
            }

            MobileButton {
                Layout.fillWidth: true
                text: "RECORR."
                accent: root.filter === "recurring"
                quiet: root.filter !== "recurring"
                onClicked: root.filter = "recurring"
            }

            MobileButton {
                Layout.fillWidth: true
                text: "ÚNICAS"
                accent: root.filter === "single"
                quiet: root.filter !== "single"
                onClicked: root.filter = "single"
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
                            Layout.preferredHeight: 46
                            color: MobileTheme.surface
                            radius: MobileTheme.radius


                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 4
                                spacing: 8

                                Text {
                                    text: groupSection.expanded ? "▾" : "▸"
                                    color: MobileTheme.subdued
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.bodySize
                                }

                                Rectangle {
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 28
                                    radius: 3
                                    color: groupSection.modelData.color
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: groupSection.modelData.name.toUpperCase()
                                          + " · " + groupSection.modelData.tasks.length
                                    color: groupSection.modelData.id === ""
                                           ? MobileTheme.foreground : groupSection.modelData.color
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.bodySmallSize
                                    font.bold: true
                                    font.letterSpacing: 0.7
                                    elide: Text.ElideRight
                                }

                                MobileButton {
                                    Layout.preferredWidth: 44
                                    text: "+"
                                    quiet: true
                                    Accessible.name: "Criar tarefa em " + groupSection.modelData.name
                                    onClicked: root.createTask(groupSection.modelData.id)
                                }

                                MobileButton {
                                    visible: groupSection.modelData.id !== ""
                                    Layout.preferredWidth: 44
                                    text: "···"
                                    quiet: true
                                    Accessible.name: "Gerenciar lista " + groupSection.modelData.name
                                    onClicked: listManager.openForEdit(groupSection.modelData)
                                }
                            }
                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.rightMargin: groupSection.modelData.id === "" ? 56 : 108
                                Accessible.id: "tasks-list-group-"
                                               + root.groupKey(String(groupSection.modelData.id || ""))
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

                            Rectangle {
                                id: taskRow
                                required property var modelData
                                visible: groupSection.expanded
                                Layout.fillWidth: true
                                implicitHeight: visible ? taskContent.implicitHeight + 20 : 0
                                color: "transparent"

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: MobileTheme.divider
                                }

                                Rectangle {
                                    visible: taskRow.modelData.categoryName !== ""
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    radius: 1
                                    color: taskRow.modelData.categoryColor || MobileTheme.accent
                                }

                                RowLayout {
                                    id: taskContent
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 2
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 10

                                    Text {
                                        text: taskRow.modelData.emoji
                                              || (taskRow.modelData.recurring ? "↻" : "·")
                                        color: taskRow.modelData.completed
                                               ? MobileTheme.disabled : MobileTheme.foreground
                                        font.pixelSize: 20
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: taskRow.modelData.title
                                            color: taskRow.modelData.completed
                                                   ? MobileTheme.disabled
                                                   : taskRow.modelData.categoryName !== ""
                                                     ? taskRow.modelData.categoryColor
                                                       || MobileTheme.accent
                                                     : MobileTheme.foreground
                                            font.family: MobileTheme.fontFamily
                                            font.pixelSize: MobileTheme.bodySize
                                            font.bold: true
                                            font.strikeout: taskRow.modelData.completed
                                            wrapMode: Text.Wrap
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                const parts = [root.portugueseLocale.toString(
                                                    new Date(taskRow.modelData.scheduledDate
                                                             + "T00:00:00"), "dd MMM"),
                                                    taskRow.modelData.scheduledTime];
                                                parts.push(taskRow.modelData.recurring
                                                           ? taskRow.modelData.recurrenceLabel
                                                           : "ÚNICA");
                                                return parts.join(" · ");
                                            }
                                            color: taskRow.modelData.completed
                                                   ? MobileTheme.disabled : MobileTheme.subdued
                                            font.family: MobileTheme.fontFamily
                                            font.pixelSize: MobileTheme.captionSize
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: taskRow.modelData.completed
                                            text: taskRow.modelData.completionLabel
                                            color: taskRow.modelData.completionLate
                                                   ? MobileTheme.warning : MobileTheme.subdued
                                            font.family: MobileTheme.fontFamily
                                            font.pixelSize: MobileTheme.captionSize
                                            wrapMode: Text.Wrap
                                        }
                                    }

                                    MobileButton {
                                        Layout.preferredWidth: 76
                                        text: "EDITAR"
                                        quiet: true
                                        Accessible.id: "tasks-edit-" + taskRow.modelData.taskId
                                        onClicked: taskEditor.openForEdit(taskRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.filteredTasks.length === 0
                    text: root.controller.allTasks.length === 0
                          ? "Crie sua primeira tarefa."
                          : "Nenhuma tarefa corresponde ao filtro."
                    color: MobileTheme.disabled
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 24
                }

                Item { Layout.preferredHeight: 16 }
            }
        }
    }
}
