pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property alias text: input.text
    readonly property bool acceptableInput: input.acceptableInput
    property int pendingHour: 0
    property int pendingMinute: 0
    readonly property var minuteOptions: [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    signal accepted()
    signal textEdited()

    implicitWidth: 116
    implicitHeight: WaypointTheme.controlHeight

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function currentTime() {
        const now = new Date();
        return { hour: now.getHours(), minute: now.getMinutes() };
    }

    function forceActiveFocus() {
        input.forceActiveFocus();
    }

    function selectAll() {
        input.selectAll();
    }

    function openPicker() {
        if (input.acceptableInput) {
            const parts = input.text.split(":");
            pendingHour = Number(parts[0]);
            pendingMinute = Number(parts[1]);
        } else {
            const now = currentTime();
            pendingHour = now.hour;
            pendingMinute = now.minute;
        }
        picker.open();
    }

    function selectCurrentTime() {
        const now = currentTime();
        pendingHour = now.hour;
        pendingMinute = now.minute;
    }

    function applySelection() {
        input.text = pad(pendingHour) + ":" + pad(pendingMinute);
        root.textEdited();
        picker.close();
    }

    RowLayout {
        anchors.fill: parent
        spacing: 4

        AppTextField {
            id: input
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: "HH:mm"
            horizontalAlignment: TextInput.AlignHCenter
            inputMethodHints: Qt.ImhTime
            validator: RegularExpressionValidator {
                regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
            }
            onTextEdited: root.textEdited()
            onAccepted: root.accepted()
        }

        AppButton {
            Layout.preferredWidth: WaypointTheme.controlHeight
            Layout.fillHeight: true
            square: true
            text: "◷"
            onClicked: root.openPicker()
            ToolTip.visible: hovered
            ToolTip.text: "Selecionar horário"
        }
    }

    Popup {
        id: picker
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(380, parent.width - 24)
        padding: WaypointTheme.popupPadding
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

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

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.pad(root.pendingHour) + ":" + root.pad(root.pendingMinute)
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.displayLargeSize
                font.bold: true
            }

            Text {
                text: "HORA"
                color: WaypointTheme.subduedText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.bold: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 6
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: 24

                    AppButton {
                        required property int index
                        Layout.fillWidth: true
                        text: root.pad(index)
                        selected: root.pendingHour === index
                        onClicked: root.pendingHour = index
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
                Layout.fillWidth: true
                columns: 6
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: root.minuteOptions

                    AppButton {
                        required property int index
                        required property int modelData
                        Layout.fillWidth: true
                        text: root.pad(modelData)
                        selected: root.pendingMinute === modelData
                        onClicked: root.pendingMinute = modelData
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
                    onClicked: picker.close()
                }
                AppButton {
                    text: "Concluir"
                    selected: true
                    onClicked: root.applySelection()
                }
            }
        }
    }
}
