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
        id: trigger
        anchors.fill: parent
        text: "Lembretes · " + root.reminderTimes.length
        onClicked: reminderPopup.open()
        contentItem: RowLayout {
            spacing: 6
            AppIcon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                name: "bell"
                color: WaypointTheme.subduedText
            }
            Text {
                Layout.fillWidth: true
                text: trigger.text
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.bodySmallSize
                font.weight: WaypointTheme.weightMedium
                font.features: WaypointTheme.tabularNumbers
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
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
            radius: WaypointTheme.radiusLarge
            color: WaypointTheme.popupFill
            border.width: 1
            border.color: WaypointTheme.controlBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Lembretes"
                    color: WaypointTheme.foreground
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.headingSize
                    font.weight: WaypointTheme.weightSemiBold
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.reminderTimes.length + " / " + root.maximumReminderCount
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                    font.features: WaypointTheme.tabularNumbers
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
                        font.weight: WaypointTheme.weightMedium
                        font.features: WaypointTheme.tabularNumbers
                    }
                    AppButton {
                        text: "Remover"
                        flat: true
                        destructive: true
                        onClicked: root.removeTime(parent.modelData)
                    }
                }
            }

            AppButton {
                id: addButton
                Layout.fillWidth: true
                enabled: root.reminderTimes.length < root.maximumReminderCount
                text: "Adicionar horário"
                onClicked: timePicker.openPicker()
                contentItem: Row {
                    spacing: 6
                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        name: "plus"
                        color: addButton.enabled ? WaypointTheme.subduedText : WaypointTheme.disabledText
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: addButton.text
                        color: addButton.enabled ? WaypointTheme.foreground : WaypointTheme.disabledText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                        font.weight: WaypointTheme.weightMedium
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                AppButton {
                    text: "Concluir"
                    highlighted: true
                    onClicked: reminderPopup.close()
                }
            }
        }
    }
}
