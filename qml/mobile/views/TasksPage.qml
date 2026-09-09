pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    property string filter: "all"
    property string categoryFilterId: "__all"
    readonly property var filteredTasks: {
        const query = searchField.text.trim().toLocaleLowerCase();
        const values = [];
        for (const task of controller.allTasks) {
            const recurring = task.recurring === true;
            if (filter === "recurring" && !recurring)
                continue;
            if (filter === "single" && recurring)
                continue;
            const taskCategoryId = String(task.categoryId || "");
            if ((categoryFilterId === "__uncategorized" && taskCategoryId !== "")
                    || (categoryFilterId !== "__all"
                        && categoryFilterId !== "__uncategorized"
                        && taskCategoryId !== categoryFilterId))
                continue;
            const searchable = String(task.title || "") + " "
                             + String(task.categoryName || "");
            if (query !== "" && searchable.toLocaleLowerCase().indexOf(query) < 0)
                continue;
            values.push(task);
        }
        return values;
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

    function createTask() {
        taskEditor.openForCreate(controller.todayKey);
    }

    TaskEditor {
        id: taskEditor
        controller: root.controller
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

            Item {
                Layout.fillWidth: true
            }

            MobileButton {
                Layout.preferredWidth: 104
                text: "+ TAREFA"
                accent: true
                Accessible.id: "tasks-create-task"
                onClicked: root.createTask()
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
        TaskCategoryFilter {
            Layout.fillWidth: true
            categories: root.controller.taskCategories
            selectedCategoryId: root.categoryFilterId
            onCategorySelected: categoryId => root.categoryFilterId = categoryId
        }


        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.filteredTasks

                    delegate: Rectangle {
                        id: taskRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: taskContent.implicitHeight + 20
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
                                text: taskRow.modelData.emoji || (taskRow.modelData.recurring ? "↻" : "·")
                                color: taskRow.modelData.completed ? MobileTheme.disabled
                                                                   : MobileTheme.foreground
                                font.pixelSize: 20
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: taskRow.modelData.title
                                    color: taskRow.modelData.completed ? MobileTheme.disabled
                                         : taskRow.modelData.categoryName !== ""
                                           ? taskRow.modelData.categoryColor || MobileTheme.accent
                                           : MobileTheme.foreground
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.bodySize
                                    font.bold: true
                                    font.strikeout: taskRow.modelData.completed
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: taskRow.modelData.categoryName !== ""
                                    text: String(taskRow.modelData.categoryName || "").toUpperCase()
                                    color: taskRow.modelData.completed ? MobileTheme.disabled
                                         : taskRow.modelData.categoryColor || MobileTheme.accent
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.captionSize
                                    font.bold: true
                                    font.letterSpacing: 0.6
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        const parts = [Qt.formatDate(
                                            new Date(taskRow.modelData.scheduledDate + "T00:00:00"),
                                            "dd MMM"), taskRow.modelData.scheduledTime];
                                        if (taskRow.modelData.recurring)
                                            parts.push(taskRow.modelData.recurrenceLabel);
                                        else
                                            parts.push("ÚNICA");
                                        if (taskRow.modelData.completed)
                                            parts.push("CONCLUÍDA");
                                        return parts.join(" · ");
                                    }
                                    color: taskRow.modelData.completed ? MobileTheme.disabled
                                                                       : MobileTheme.subdued
                                    font.family: MobileTheme.fontFamily
                                    font.pixelSize: MobileTheme.captionSize
                                    elide: Text.ElideRight
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

                Item {
                    Layout.preferredHeight: 16
                }
            }
        }
    }
}
