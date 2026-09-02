pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var reminderTimes: []
    readonly property int maximumReminderCount: 10

    implicitWidth: 180
    implicitHeight: WaypointTheme.controlHeight

    function setReminderTimes(values) {
        const normalized = [];
        for (const value of (values || [])) {
            const time = String(value);
            if (/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time)
                    && normalized.indexOf(time) < 0
                    && normalized.length < maximumReminderCount)
                normalized.push(time);
        }
        normalized.sort();
        reminderTimes = normalized;
    }

    function addTime(time) {
        const updated = reminderTimes.slice();
        if (updated.indexOf(time) < 0 && updated.length < maximumReminderCount) {
            updated.push(time);
            updated.sort();
            reminderTimes = updated;
        }
    }

    function removeTime(time) {
        const updated = reminderTimes.slice();
        const index = updated.indexOf(time);
        if (index >= 0) {
            updated.splice(index, 1);
            reminderTimes = updated;
        }
    }

    AppButton {
        anchors.fill: parent
        text: "Lembretes · " + root.reminderTimes.length
        onClicked: reminderPopup.open()
    }

    AppTimePicker {
        id: timePicker
        showInlineButton: false
        text: "08:00"
        onSelectionAccepted: selectedTime => root.addTime(selectedTime)
    }

    Popup {
        id: reminderPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(360, parent.width - 24)
        padding: WaypointTheme.popupPadding
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle { color: WaypointTheme.scrim }
        background: Rectangle {
            radius: WaypointTheme.radius
            color: WaypointTheme.background
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "LEMBRETES"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.titleSize
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.reminderTimes.length + " / " + root.maximumReminderCount
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.reminderTimes.length === 0
                text: "Nenhum horário adicionado."
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
            }

            Repeater {
                model: root.reminderTimes

                RowLayout {
                    required property string modelData
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: parent.modelData
                        color: WaypointTheme.foreground
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySize
                        font.bold: true
                    }
                    AppButton {
                        text: "Remover"
                        destructive: true
                        onClicked: root.removeTime(parent.modelData)
                    }
                }
            }

            AppButton {
                Layout.fillWidth: true
                enabled: root.reminderTimes.length < root.maximumReminderCount
                text: "+ Adicionar horário"
                onClicked: timePicker.openPicker()
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                AppButton {
                    text: "Concluir"
                    selected: true
                    onClicked: reminderPopup.close()
                }
            }
        }
    }
}
