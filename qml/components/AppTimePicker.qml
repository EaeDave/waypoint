pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property alias text: pickerInput.text
    property bool showInlineButton: true
    property bool focusAcceptOnOpen: false
    readonly property bool acceptableInput: pickerInput.acceptableInput
    property int pendingHour: 0
    property int pendingMinute: 0
    property string originalText: ""
    property bool committing: false

    signal selectionAccepted(string selectedTime)

    implicitWidth: showInlineButton ? 132 : 0
    implicitHeight: showInlineButton ? WaypointTheme.controlHeight : 0

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function currentTime() {
        const now = new Date();
        return { hour: now.getHours(), minute: now.getMinutes() };
    }

    function updateTextFromSelection() {
        pickerInput.text = pad(pendingHour) + ":" + pad(pendingMinute);
    }

    function syncSelectionFromText() {
        if (!pickerInput.acceptableInput)
            return;
        const parts = pickerInput.text.split(":");
        pendingHour = Number(parts[0]);
        pendingMinute = Number(parts[1]);
    }

    function forceActiveFocus() {
        openPicker();
    }

    function openPicker() {
        originalText = pickerInput.text;
        committing = false;
        if (pickerInput.acceptableInput) {
            syncSelectionFromText();
        } else {
            const now = currentTime();
            pendingHour = now.hour;
            pendingMinute = now.minute;
            updateTextFromSelection();
        }
        picker.open();
    }

    function selectCurrentTime() {
        const now = currentTime();
        pendingHour = now.hour;
        pendingMinute = now.minute;
        updateTextFromSelection();
    }

    function chooseHour(hour) {
        pendingHour = hour;
        updateTextFromSelection();
    }

    function chooseMinute(minute) {
        pendingMinute = minute;
        updateTextFromSelection();
    }

    function cancelSelection() {
        pickerInput.text = originalText;
        picker.close();
    }

    function applySelection() {
        if (!pickerInput.acceptableInput)
            return;
        syncSelectionFromText();
        committing = true;
        const selectedTime = pickerInput.text;
        picker.close();
        root.selectionAccepted(selectedTime);
    }

    AppButton {
        anchors.fill: parent
        visible: root.showInlineButton
        text: root.acceptableInput ? pickerInput.text + "  ◷" : "Selecionar horário  ◷"
        onClicked: root.openPicker()
    }

    Popup {
        id: picker
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(460, parent.width - 24)
        padding: WaypointTheme.popupPadding
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            if (root.focusAcceptOnOpen)
                Qt.callLater(() => acceptButton.forceActiveFocus());
        }
        onClosed: {
            if (!root.committing)
                pickerInput.text = root.originalText;
            root.committing = false;
        }

        Overlay.modal: Rectangle {
            color: WaypointTheme.scrim
        }

        background: Rectangle {
            radius: WaypointTheme.radius
            color: WaypointTheme.background
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap

            Text {
                text: "SELECIONAR HORÁRIO"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.titleSize
                font.bold: true
            }

            TextField {
                id: pickerInput
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 160
                placeholderText: "HH:mm"
                color: WaypointTheme.foreground
                placeholderTextColor: WaypointTheme.disabledText
                selectionColor: WaypointTheme.accent
                selectedTextColor: WaypointTheme.background
                horizontalAlignment: TextInput.AlignHCenter
                inputMethodHints: Qt.ImhTime
                selectByMouse: true
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.displayLargeSize
                font.bold: true
                validator: RegularExpressionValidator {
                    regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
                }
                background: Item {}
                onTextEdited: root.syncSelectionFromText()
                onAccepted: root.applySelection()
            }

            Text {
                text: "HORA"
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.bold: true
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 6
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: 24

                    AppButton {
                        required property int index
                        square: true
                        text: root.pad(index)
                        selected: root.pendingHour === index
                        onClicked: root.chooseHour(index)
                    }
                }
            }

            Text {
                text: "MINUTO"
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.bold: true
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 10
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: 60

                    AppButton {
                        required property int index
                        square: true
                        text: root.pad(index)
                        selected: root.pendingMinute === index
                        onClicked: root.chooseMinute(index)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                AppButton {
                    text: "Agora"
                    onClicked: root.selectCurrentTime()
                }
                Item {
                    Layout.fillWidth: true
                }
                AppButton {
                    text: "Cancelar"
                    onClicked: root.cancelSelection()
                }
                AppButton {
                    id: acceptButton
                    text: "Concluir"
                    selected: true
                    enabled: root.acceptableInput
                    onClicked: root.applySelection()
                }
            }
        }
    }
}
