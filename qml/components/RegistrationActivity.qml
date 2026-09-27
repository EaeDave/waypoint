pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var groups
    required property var completionActions
    property string dateKey: ""
    property bool expanded: false
    property var expandedTasks: ({})
    visible: groups.length > 0
    spacing: 8
    onDateKeyChanged: {
        expanded = false;
        expandedTasks = ({});
    }

    AppButton {
        Layout.fillWidth: true
        text: (root.expanded ? "▾ " : "▸ ") + "Conclusões registradas neste dia"
        Accessible.name: (root.expanded ? "Recolher" : "Expandir") + " conclusões registradas neste dia"
        onClicked: root.expanded = !root.expanded
    }

    Text {
        Layout.fillWidth: true
        visible: root.expanded
        text: "Ocorrências de outras datas. O histórico permanece na data prevista."
        color: WaypointTheme.subduedText
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.bodySmallSize
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.expanded ? root.groups : []
        delegate: ColumnLayout {
            id: taskGroup
            required property var modelData
            readonly property bool expanded: root.expandedTasks[modelData.taskId] === true
            Layout.fillWidth: true
            spacing: 4

            AppButton {
                Layout.fillWidth: true
                text: (taskGroup.expanded ? "▾ " : "▸ ")
                    + (taskGroup.modelData.emoji ? taskGroup.modelData.emoji + " " : "")
                    + taskGroup.modelData.title + " · " + taskGroup.modelData.count
                    + (taskGroup.modelData.count === 1 ? " conclusão" : " conclusões")
                onClicked: {
                    const next = Object.assign({}, root.expandedTasks);
                    next[taskGroup.modelData.taskId] = !taskGroup.expanded;
                    root.expandedTasks = next;
                }
            }
            Text {
                Layout.fillWidth: true
                text: taskGroup.modelData.dateSummary
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: taskGroup.expanded ? taskGroup.modelData.occurrences : []
                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: entryContent.implicitHeight + 16
                    color: WaypointTheme.controlFill
                    radius: WaypointTheme.radius
                    ColumnLayout {
                        id: entryContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: {
                                const parts = entry.modelData.occurrenceDate.split("-");
                                const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
                                return "PREVISTA " + Qt.locale("pt_BR").toString(date, "dd/MM/yyyy")
                                    + (entry.modelData.categoryName ? " · " + entry.modelData.categoryName : "");
                            }
                            color: WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.captionSize
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.completionLabel
                            color: entry.modelData.completionLate ? WaypointTheme.warning : WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.captionSize
                            wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            AppButton {
                                text: "Alterar data"
                                onClicked: root.completionActions.choose(entry.modelData.taskId,
                                    entry.modelData.occurrenceDate, entry.modelData.completedDate || "", true)
                            }
                            AppButton {
                                text: "Desfazer"
                                onClicked: root.completionActions.commit(entry.modelData.taskId,
                                    entry.modelData.occurrenceDate, false, "")
                            }
                        }
                    }
                }
            }
        }
    }
}
