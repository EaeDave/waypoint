import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    required property string taskId
    required property string title
    required property string scheduledDateKey
    required property string scheduledTimeKey
    required property bool completed
    required property bool overdue
    required property bool recurring
    required property string recurrenceLabel
    required property var controller

    readonly property date scheduledDateValue: {
        const parts = scheduledDateKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    implicitHeight: root.overdue || root.recurring ? 62 : 50
    radius: 7
    color: pointer.containsMouse ? "#151519" : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: 4
            color: root.completed ? "#a997ff" : "transparent"
            border.width: 1
            border.color: root.completed ? "#a997ff" : (root.overdue ? "#ff7085" : "#77737e")

            Text {
                anchors.centerIn: parent
                visible: root.completed
                text: "✓"
                color: "#0a090c"
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.controller.setOccurrenceCompleted(root.taskId,
                                                                   root.scheduledDateKey,
                                                                   !root.completed)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.completed ? "#716e77" : "#f2f0f5"
                elide: Text.ElideRight
                font.family: "sans-serif"
                font.pixelSize: 14
                font.strikeout: root.completed
            }

            Text {
                visible: root.overdue || root.recurring
                text: {
                    const recurrence = root.recurring ? root.recurrenceLabel : "";
                    if (!root.overdue)
                        return recurrence;
                    const overdue = "ATRASADA · " + Qt.formatDate(root.scheduledDateValue, "dd MMM");
                    return recurrence === "" ? overdue : overdue + " · " + recurrence;
                }
                color: root.overdue ? "#ff7085" : "#a997ff"
                font.family: "monospace"
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1
            }
        }

        TextField {
            id: timeEditor
            Layout.preferredWidth: 58
            text: root.scheduledTimeKey
            color: root.completed ? "#716e77" : "#d7d3dc"
            horizontalAlignment: TextInput.AlignHCenter
            font.family: "monospace"
            font.pixelSize: 11
            selectByMouse: true
            validator: RegularExpressionValidator {
                regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
            }
            background: Rectangle {
                radius: 5
                color: timeEditor.activeFocus ? "#24212c" : "transparent"
                border.width: timeEditor.activeFocus ? 1 : 0
                border.color: "#8f7fe1"
            }
            onEditingFinished: {
                const normalizedTime = text.trim();
                if (acceptableInput && normalizedTime !== root.scheduledTimeKey)
                    root.controller.rescheduleTask(root.taskId,
                                                   root.scheduledDateKey,
                                                   normalizedTime);
                else if (!acceptableInput)
                    text = root.scheduledTimeKey;
            }
            ToolTip.visible: hovered
            ToolTip.text: "Editar horário"
        }

        ToolButton {
            text: root.recurring ? "⋯" : "×"
            visible: pointer.containsMouse
            onClicked: {
                if (root.recurring)
                    deleteMenu.open();
                else
                    root.controller.deleteOccurrence(root.taskId,
                                                     root.scheduledDateKey,
                                                     "series");
            }
            ToolTip.visible: hovered
            ToolTip.text: root.recurring ? "Opções da recorrência" : "Excluir tarefa"

            Menu {
                id: deleteMenu
                MenuItem {
                    text: "Excluir esta ocorrência"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "occurrence")
                }
                MenuItem {
                    text: "Excluir esta e as seguintes"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "following")
                }
                MenuSeparator {}
                MenuItem {
                    text: "Excluir toda a série"
                    onTriggered: root.controller.deleteOccurrence(root.taskId,
                                                                  root.scheduledDateKey,
                                                                  "series")
                }
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }
}
