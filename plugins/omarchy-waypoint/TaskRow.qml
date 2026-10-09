pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Rectangle {
    id: root
    required property var task
    required property date today
    required property color foreground
    required property string fontFamily
    required property string monospaceFontFamily
    property color completionLateColor: "#d9a441"
    readonly property bool overdue: !task.completed && !task.skipped && String(task.occurrenceDate || "") < Model.dateKey(today)
    readonly property string statusLabel: {
        if (task.completed)
            return task.completionLabel || "Concluída";
        if (!task.skipped && !overdue)
            return "";
        return (task.skipped ? "Não feita" : "Atrasada") + " · " + Qt.locale("pt_BR").toString(Model.parseLocalDate(task.occurrenceDate), "dd MMM");
    }
    readonly property string detailsTooltip: {
        const details = [String(task.title || "")];
        if (task.recurring && task.recurrenceLabel)
            details.push("Repetição: " + task.recurrenceLabel);
        const reminders = task.reminderMinutesBefore || [];
        if (reminders.length > 0)
            details.push("Lembretes: " + reminders.map(minutes => minutes === 0 ? "no horário" : minutes + " min antes").join(", "));
        return details.join("\n");
    }

    signal completionRequested(var task)
    signal editRequested(var task)

    implicitHeight: Math.max(Style.space(72), taskDetails.implicitHeight + Style.space(24))
    radius: Math.max(Style.cornerRadius, Style.space(6))
    color: taskMouse.containsMouse ? Style.hoverFillFor(foreground, Color.accent) : "transparent"

    MouseArea {
        id: taskMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.editRequested(root.task);
            else
                root.completionRequested(root.task);
        }
    }

    ToolTip.visible: taskMouse.containsMouse
    ToolTip.delay: 700
    ToolTip.text: detailsTooltip

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Style.space(12)
        height: Style.spacing.hairline
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(10)

        Button {
            Layout.preferredWidth: Style.space(34)
            Layout.preferredHeight: Style.space(34)
            text: root.task.completed ? "󰄲" : root.task.skipped ? "×" : "󰄱"
            fontFamily: root.monospaceFontFamily
            fontSize: Style.space(19)
            foreground: root.task.completed ? Color.accent : root.task.skipped ? Color.urgent : root.foreground
            focusable: true
            tooltipText: root.task.completed || root.task.skipped ? "Reabrir tarefa" : "Concluir tarefa"
            Accessible.role: Accessible.CheckBox
            Accessible.name: tooltipText + ": " + root.task.title
            Accessible.checked: root.task.completed === true
            Accessible.onPressAction: clicked()
            onClicked: root.completionRequested(root.task)
        }

        Text {
            Layout.preferredWidth: Style.space(24)
            visible: String(root.task.emoji || "") !== ""
            text: root.task.emoji || ""
            font.family: "Noto Color Emoji"
            font.pixelSize: Style.space(18)
            horizontalAlignment: Text.AlignHCenter
        }

        Column {
            id: taskDetails
            Layout.fillWidth: true
            spacing: Style.space(5)

            Text {
                width: parent.width
                text: root.task.title
                color: root.task.completed ? Qt.darker(root.foreground, 1.6) : root.foreground
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: Style.space(15)
                font.weight: Font.DemiBold
                font.strikeout: root.task.completed
            }

            RowLayout {
                width: parent.width
                spacing: Style.space(6)
                visible: String(root.task.categoryName || "") !== "" || root.task.recurring

                Rectangle {
                    Layout.preferredWidth: Style.space(6)
                    Layout.preferredHeight: Style.space(6)
                    radius: width / 2
                    visible: String(root.task.categoryName || "") !== ""
                    color: root.task.categoryColor || Color.accent
                }
                Text {
                    Layout.fillWidth: true
                    text: String(root.task.categoryName || "")
                    color: Qt.darker(root.foreground, 1.4)
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(11)
                }
                Text {
                    visible: root.task.recurring === true && !root.task.completed
                    text: "↻"
                    color: Qt.darker(root.foreground, 1.4)
                    font.pixelSize: Style.space(13)
                }
            }

            Text {
                width: parent.width
                visible: root.statusLabel !== ""
                text: root.statusLabel
                color: root.task.skipped || root.overdue ? Color.urgent : root.task.completionLate ? root.completionLateColor : Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.space(11)
                wrapMode: Text.Wrap
            }
        }

        Text {
            Layout.preferredWidth: Style.space(56)
            visible: String(root.task.scheduledTime || "") !== ""
            text: String(root.task.scheduledTime || "")
            color: root.task.completed ? Qt.darker(root.foreground, 1.6) : root.overdue || root.task.skipped ? Color.urgent : Color.accent
            horizontalAlignment: Text.AlignRight
            font.family: root.monospaceFontFamily
            font.pixelSize: Style.space(14)
            font.weight: Font.DemiBold
        }

        Button {
            Layout.preferredWidth: Style.space(34)
            Layout.preferredHeight: Style.space(34)
            text: "⋯"
            fontFamily: root.fontFamily
            fontSize: Style.space(18)
            foreground: root.foreground
            focusable: true
            tooltipText: "Editar ou excluir tarefa"
            Accessible.role: Accessible.Button
            Accessible.name: tooltipText + ": " + root.task.title
            Accessible.onPressAction: clicked()
            onClicked: root.editRequested(root.task)
        }
    }
}
