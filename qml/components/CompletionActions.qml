pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var controller
    property string taskId: ""
    property string dueDate: ""
    property string actualDate: ""
    property bool editing: false
    property bool choosingDate: false
    property string commitError: ""
    property string feedbackTaskId: ""
    property string feedbackDueDate: ""
    property string feedbackDate: ""
    property bool feedbackCompleted: false
    property bool feedbackEdited: false
    property string feedbackPreviousDate: ""
    property string feedbackText: ""

    function todayKey() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    function choose(taskId, dueDate, actualDate, editing) {
        root.taskId = taskId;
        root.dueDate = dueDate;
        root.actualDate = actualDate;
        root.editing = editing;
        root.choosingDate = editing;
        root.commitError = "";
        dateInput.text = actualDate;
        picker.open();
    }

    function toggle(taskId, dueDate, completed, skipped, overdue) {
        if (completed || skipped) {
            commit(taskId, dueDate, false, "");
        } else if (overdue) {
            choose(taskId, dueDate, "", false);
        } else {
            commit(taskId, dueDate, true, todayKey());
        }
    }

    function commit(taskId, dueDate, completed, dateKey, previousDate) {
        root.commitError = "";
        if (!root.controller.setOccurrenceCompleted(taskId, dueDate, completed, dateKey)) {
            root.commitError = root.controller.errorMessage;
            return false;
        }
        root.feedbackTaskId = taskId;
        root.feedbackDueDate = dueDate;
        root.feedbackDate = dateKey;
        root.feedbackCompleted = completed;
        root.feedbackEdited = previousDate !== undefined;
        root.feedbackPreviousDate = previousDate === undefined ? "" : previousDate;
        root.feedbackText = !completed ? "Ocorrência reaberta."
            : root.feedbackEdited ? "Data da conclusão alterada." : "Conclusão registrada.";
        feedback.open();
        feedbackTimer.restart();
        return true;
    }

    function saveDate(dateKey) {
        if (commit(root.taskId, root.dueDate, true, dateKey, root.editing ? root.actualDate : undefined))
            picker.close();
    }

    function undoFeedback() {
        const restoreDate = root.feedbackEdited && root.feedbackPreviousDate !== "";
        if (!root.controller.setOccurrenceCompleted(root.feedbackTaskId, root.feedbackDueDate,
                restoreDate, restoreDate ? root.feedbackPreviousDate : "")) {
            root.feedbackText = root.controller.errorMessage;
            feedbackTimer.restart();
            return;
        }
        root.feedbackCompleted = false;
        root.feedbackText = restoreDate ? "Data anterior restaurada." : "Ocorrência reaberta.";
        feedbackTimer.restart();
    }

    Popup {
        id: picker
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(390, parent.width - 24)
        padding: WaypointTheme.popupPadding
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: WaypointTheme.scrim }
        background: Rectangle {
            color: WaypointTheme.background
            radius: WaypointTheme.radius
            border.color: WaypointTheme.activeBorder
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: root.editing ? "Alterar data da conclusão" : "Quando você concluiu?"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.titleSize
                font.bold: true
                wrapMode: Text.WordWrap
            }
            AppButton {
                Layout.fillWidth: true
                text: "Hoje"
                onClicked: root.saveDate(root.todayKey())
            }
            AppButton {
                Layout.fillWidth: true
                text: "Na data prevista"
                enabled: root.controller.completionDateError(root.dueDate) === ""
                onClicked: root.saveDate(root.dueDate)
            }
            AppButton {
                Layout.fillWidth: true
                text: "Escolher data"
                onClicked: {
                    root.choosingDate = true;
                    dateInput.forceActiveFocus();
                }
            }
            AppTextField {
                id: dateInput
                Layout.fillWidth: true
                visible: root.choosingDate
                placeholderText: "AAAA-MM-DD"
                Accessible.name: "Data real da conclusão, ano-mês-dia"
                onTextChanged: root.commitError = ""
                onAccepted: {
                    if (root.controller.completionDateError(text) === "")
                        root.saveDate(text);
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.commitError !== "" ? root.commitError
                    : root.choosingDate ? root.controller.completionDateError(dateInput.text) : ""
                color: WaypointTheme.warning
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                AppButton {
                    text: "Cancelar"
                    onClicked: picker.close()
                }
                AppButton {
                    visible: root.choosingDate
                    text: "Salvar"
                    enabled: root.controller.completionDateError(dateInput.text) === ""
                    onClicked: root.saveDate(dateInput.text)
                }
            }
        }
    }

    Popup {
        id: feedback
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: parent.height - height - 20
        width: Math.min(470, parent.width - 24)
        padding: 12
        closePolicy: Popup.CloseOnEscape
        background: Rectangle {
            color: WaypointTheme.background
            border.color: WaypointTheme.controlBorder
            radius: WaypointTheme.radius
        }
        contentItem: ColumnLayout {
            Text {
                Layout.fillWidth: true
                text: root.feedbackText
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySize
                wrapMode: Text.WordWrap
            }
            RowLayout {
                visible: root.feedbackCompleted
                AppButton {
                    text: root.feedbackEdited && root.feedbackPreviousDate === "" ? "REABRIR TAREFA" : "DESFAZER"
                    onClicked: root.undoFeedback()
                }
                AppButton {
                    text: "ALTERAR DATA"
                    onClicked: {
                        feedback.close();
                        root.choose(root.feedbackTaskId, root.feedbackDueDate, root.feedbackDate, true);
                    }
                }
            }
        }
    }

    Timer {
        id: feedbackTimer
        interval: 8000
        onTriggered: feedback.close()
    }
}
