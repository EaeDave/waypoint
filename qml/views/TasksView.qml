pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var controller
    property string filter: "all"
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

            Item {
                Layout.fillWidth: true
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

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.filteredTasks.length + " exibida"
                      + (root.filteredTasks.length === 1 ? "" : "s")
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
            }
        }

        ListView {
            id: taskList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.filteredTasks

            delegate: Item {
                id: taskDelegate
                required property var modelData
                width: taskList.width
                height: taskRow.implicitHeight

                TaskRow {
                    id: taskRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    taskId: taskDelegate.modelData.taskId
                    title: taskDelegate.modelData.title
                    scheduledDateKey: taskDelegate.modelData.scheduledDate
                    scheduledTimeKey: taskDelegate.modelData.scheduledTime
                    emoji: taskDelegate.modelData.emoji || ""
                    categoryId: taskDelegate.modelData.categoryId || ""
                    categoryName: taskDelegate.modelData.categoryName || ""
                    categoryColor: taskDelegate.modelData.categoryColor || WaypointTheme.accent
                    completed: taskDelegate.modelData.completed === true
                    skipped: false
                    overdue: false
                    recurring: taskDelegate.modelData.recurring === true
                    recurrenceLabel: taskDelegate.modelData.recurrenceLabel || ""
                    recurrence: taskDelegate.modelData.recurrence || ({})
                    reminderMinutesBefore: taskDelegate.modelData.reminderMinutesBefore || []
                    controller: root.controller
                    definitionMode: true
                }
            }

            Text {
                anchors.centerIn: parent
                visible: taskList.count === 0
                text: root.controller.allTasks.length === 0
                      ? "Crie sua primeira tarefa acima."
                      : "Nenhuma tarefa corresponde ao filtro."
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
            }
        }
    }

    Shortcut {
        sequence: "N"
        onActivated: composer.focusInput()
    }
}
