import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    required property string taskId
    required property string title
    required property string scheduledDateKey
    required property bool completed
    required property bool overdue
    required property var controller

    readonly property date scheduledDateValue: {
        const parts = scheduledDateKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    implicitHeight: 50
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
                onClicked: root.controller.setTaskCompleted(root.taskId, !root.completed)
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
                visible: root.overdue
                text: "ATRASADA · " + Qt.formatDate(root.scheduledDateValue, "dd MMM")
                color: "#ff7085"
                font.family: "monospace"
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1
            }
        }

        ToolButton {
            text: "×"
            visible: pointer.containsMouse
            onClicked: root.controller.deleteTask(root.taskId)
            ToolTip.visible: hovered
            ToolTip.text: "Excluir tarefa"
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }
}
