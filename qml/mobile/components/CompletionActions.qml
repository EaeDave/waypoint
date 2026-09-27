pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var controller
    property var task: ({})
    property var previousTask: ({})
    property bool editingDate: false
    property bool customDate: false
    property string validationMessage: ""
    property string feedbackText: ""
    property bool canUndo: false
    property bool canEdit: false
    signal committed()

    function capture(value) {
        return Object.assign({}, value, {
            occurrenceDate: value.occurrenceDate || value.scheduledDate
        });
    }

    function toggle(value) {
        feedback.close();
        task = capture(value);
        if (task.completed || task.skipped) {
            if (controller.setTaskCompleted(task.taskId, task.occurrenceDate,
                                            task.recurring, false, "")) {
                feedbackText = task.skipped ? "Ocorrência reaberta." : "Conclusão desfeita.";
                canUndo = false;
                canEdit = false;
                committed();
                feedback.open();
            }
            return;
        }
        editingDate = false;
        if (task.occurrenceDate < controller.todayKey)
            openChooser(false);
        else
            complete(controller.todayKey);
    }

    function edit(value) {
        feedback.close();
        task = capture(value);
        editingDate = true;
        openChooser(true);
    }

    function openChooser(custom) {
        customDate = custom;
        validationMessage = "";
        dateField.text = task.completedDate || controller.todayKey;
        chooser.open();
    }

    function complete(dateKey) {
        if (!controller.setTaskCompleted(task.taskId, task.occurrenceDate,
                                         task.recurring, true, dateKey)) {
            validationMessage = controller.errorMessage;
            return;
        }
        previousTask = task;
        canUndo = true;
        canEdit = true;
        task = Object.assign({}, task, { completed: true, completedDate: dateKey });
        feedbackText = editingDate ? "Data da conclusão alterada." : "Conclusão registrada.";
        chooser.close();
        committed();
        feedback.open();
    }

    function undo() {
        const restoreDate = !!previousTask.completed && !!previousTask.completedDate;
        if (!controller.setTaskCompleted(previousTask.taskId, previousTask.occurrenceDate,
                                         previousTask.recurring, restoreDate,
                                         restoreDate ? previousTask.completedDate : ""))
            return;
        feedbackText = restoreDate ? "Data anterior restaurada." : "Conclusão desfeita.";
        canUndo = false;
        canEdit = false;
        committed();
        feedbackTimer.restart();
    }

    Popup {
        id: chooser
        parent: Overlay.overlay
        width: Math.min(400, parent ? parent.width - 24 : 400)
        height: Math.min(parent ? parent.height - 24 : implicitHeight,
                         chooserContent.implicitHeight + topPadding + bottomPadding)
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? Math.max(12, (parent.height - height) / 2) : 0
        modal: true
        focus: true
        padding: 16
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: MobileTheme.panel
            border.color: MobileTheme.border
            radius: MobileTheme.radius
        }
        contentItem: ScrollView {
            id: chooserScroll
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: chooserContent
                width: chooserScroll.availableWidth
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: root.editingDate ? "Alterar data da conclusão" : "Quando você concluiu?"
                    color: MobileTheme.foreground
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.titleSize
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: root.task.title || ""
                    color: MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    wrapMode: Text.Wrap
                }
                MobileButton {
                    Layout.fillWidth: true
                    text: "Hoje"
                    onClicked: root.complete(root.controller.todayKey)
                }
                MobileButton {
                    Layout.fillWidth: true
                    text: "Na data prevista"
                    enabled: !!root.task.occurrenceDate && root.task.occurrenceDate <= root.controller.todayKey
                    onClicked: root.complete(root.task.occurrenceDate)
                }
                MobileButton {
                    Layout.fillWidth: true
                    text: "Escolher data"
                    onClicked: {
                        root.customDate = true;
                        dateField.forceActiveFocus();
                    }
                }
                MobileField {
                    id: dateField
                    Layout.fillWidth: true
                    visible: root.customDate
                    placeholderText: "Data da conclusão (AAAA-MM-DD)"
                    inputMethodHints: Qt.ImhDate
                    Accessible.name: "Data da conclusão, ano-mês-dia"
                    onAccepted: root.complete(text)
                }
                Text {
                    Layout.fillWidth: true
                    text: root.validationMessage || "A data prevista não muda. Escolha uma data até hoje."
                    color: root.validationMessage ? MobileTheme.urgent : MobileTheme.subdued
                    font.family: MobileTheme.fontFamily
                    font.pixelSize: MobileTheme.bodySize
                    wrapMode: Text.Wrap
                }
                MobileButton {
                    Layout.fillWidth: true
                    visible: root.customDate
                    text: "Confirmar data"
                    accent: true
                    onClicked: root.complete(dateField.text)
                }
                MobileButton {
                    Layout.fillWidth: true
                    text: "Cancelar"
                    quiet: true
                    onClicked: chooser.close()
                }
            }
        }
    }

    Popup {
        id: feedback
        parent: Overlay.overlay
        width: Math.min(440, parent ? parent.width - 24 : 440)
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? parent.height - height - 24 : 0
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: feedbackTimer.restart()
        onClosed: feedbackTimer.stop()
        background: Rectangle {
            color: MobileTheme.panel
            border.color: MobileTheme.success
            radius: MobileTheme.radius
        }
        contentItem: ColumnLayout {
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: root.feedbackText
                color: MobileTheme.foreground
                font.family: MobileTheme.fontFamily
                font.pixelSize: MobileTheme.bodySize
                wrapMode: Text.Wrap
                Accessible.name: text
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.canUndo || root.canEdit
                MobileButton {
                    Layout.fillWidth: true
                    visible: root.canUndo
                    text: root.previousTask.completed && !root.previousTask.completedDate
                          ? "Reabrir tarefa" : "Desfazer"
                    quiet: true
                    onClicked: root.undo()
                }
                MobileButton {
                    Layout.fillWidth: true
                    visible: root.canEdit
                    text: "Alterar data"
                    quiet: true
                    onClicked: root.edit(root.task)
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
