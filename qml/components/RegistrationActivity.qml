pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../data/Labels.js" as Labels

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
        flat: true
        leftPadding: 4
        text: "Conclusões registradas neste dia"
        Accessible.name: (root.expanded ? "Recolher" : "Expandir") + " conclusões registradas neste dia"
        onClicked: root.expanded = !root.expanded
        contentItem: RowLayout {
            spacing: 6
            AppIcon {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                name: root.expanded ? "chevron-down" : "chevron-right"
                color: WaypointTheme.disabledText
            }
            Text {
                text: "Conclusões registradas neste dia"
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.weight: WaypointTheme.weightMedium
            }
        }
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

    Rectangle {
        Layout.fillWidth: true
        visible: root.expanded
        implicitHeight: groupList.implicitHeight + 8
        color: WaypointTheme.surface
        radius: WaypointTheme.radiusLarge
        border.width: 1
        border.color: WaypointTheme.controlBorder

        ColumnLayout {
            id: groupList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            spacing: 0

            Repeater {
                model: root.expanded ? root.groups : []
                delegate: ColumnLayout {
                    id: taskGroup
                    required property var modelData
                    required property int index
                    readonly property bool expanded: root.expandedTasks[modelData.taskId] === true
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        visible: taskGroup.index > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        implicitHeight: 1
                        color: WaypointTheme.divider
                    }
                    AppButton {
                        id: groupToggle
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        flat: true
                        leftPadding: 10
                        text: (taskGroup.modelData.emoji ? taskGroup.modelData.emoji + " " : "")
                            + taskGroup.modelData.title + " · " + taskGroup.modelData.count
                            + (taskGroup.modelData.count === 1 ? " conclusão" : " conclusões")
                        onClicked: {
                            const next = Object.assign({}, root.expandedTasks);
                            next[taskGroup.modelData.taskId] = !taskGroup.expanded;
                            root.expandedTasks = next;
                        }
                        contentItem: RowLayout {
                            spacing: 6
                            AppIcon {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                name: taskGroup.expanded ? "chevron-down" : "chevron-right"
                                color: WaypointTheme.subduedText
                            }
                            Text {
                                Layout.fillWidth: true
                                text: groupToggle.text
                                color: WaypointTheme.foreground
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.bodySize
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.bottomMargin: 6
                        text: taskGroup.modelData.dateSummary
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.captionSize
                        font.features: WaypointTheme.tabularNumbers
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: taskGroup.expanded ? taskGroup.modelData.occurrences : []
                        delegate: ColumnLayout {
                            id: entry
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.bottomMargin: 8
                            spacing: 6
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: WaypointTheme.divider
                            }
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const parts = entry.modelData.occurrenceDate.split("-");
                                    const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
                                    return "Prevista " + Qt.locale("pt_BR").toString(date, "dd/MM/yyyy")
                                        + (entry.modelData.categoryName ? " · " + entry.modelData.categoryName : "");
                                }
                                color: WaypointTheme.subduedText
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.captionSize
                                font.features: WaypointTheme.tabularNumbers
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                text: Labels.sentenceCase(entry.modelData.completionLabel)
                                color: entry.modelData.completionLate ? WaypointTheme.warning : WaypointTheme.subduedText
                                font.family: WaypointTheme.fontFamily
                                font.pixelSize: WaypointTheme.captionSize
                                font.features: WaypointTheme.tabularNumbers
                                wrapMode: Text.WordWrap
                            }
                            RowLayout {
                                AppButton {
                                    text: "Alterar data"
                                    flat: true
                                    onClicked: root.completionActions.choose(entry.modelData.taskId,
                                        entry.modelData.occurrenceDate, entry.modelData.completedDate || "", true)
                                }
                                AppButton {
                                    text: "Desfazer"
                                    flat: true
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
}
