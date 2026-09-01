import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    required property var controller
    required property string scheduledDateKey
    property string placeholderText: "Nova tarefa…"

    implicitHeight: 46
    radius: 7
    color: "#101013"
    border.width: input.activeFocus ? 1 : 0
    border.color: "#8f7fe1"

    function focusInput() {
        input.forceActiveFocus();
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 8
        spacing: 8

        Text {
            text: "+"
            color: "#a997ff"
            font.pixelSize: 18
        }

        TextField {
            id: input
            Layout.fillWidth: true
            placeholderText: root.placeholderText
            color: "#f2f0f5"
            placeholderTextColor: "#68656d"
            background: Item {}
            font.pixelSize: 14

            onAccepted: {
                const normalizedTitle = text.trim();
                if (normalizedTitle.length === 0)
                    return;
                if (root.controller.addTask(normalizedTitle, root.scheduledDateKey)) {
                    text = "";
                    input.forceActiveFocus();
                }
            }
        }

        Text {
            visible: input.activeFocus
            text: "ENTER"
            color: "#5f5c65"
            font.family: "monospace"
            font.pixelSize: 9
            font.letterSpacing: 1
        }
    }
}
