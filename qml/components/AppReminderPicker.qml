pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var minutesBefore: [0]
    property bool compact: false
    readonly property int maximumCount: 5
    readonly property var presets: [
        {
            label: "No horário",
            minutes: 0
        },
        {
            label: "5 minutos antes",
            minutes: 5
        },
        {
            label: "30 minutos antes",
            minutes: 30
        },
        {
            label: "1 hora antes",
            minutes: 60
        },
        {
            label: "1 dia antes",
            minutes: 1440
        }
    ]

    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight

    function setMinutesBefore(values) {
        const normalized = [];
        for (const value of (values || []))
            normalized.push(Number(value));
        normalized.sort((left, right) => right - left);
        minutesBefore = normalized;
    }

    function contains(minutes) {
        return minutesBefore.indexOf(minutes) >= 0;
    }

    function toggle(minutes) {
        const updated = minutesBefore.slice();
        const index = updated.indexOf(minutes);
        if (index >= 0)
            updated.splice(index, 1);
        else if (updated.length < maximumCount)
            updated.push(minutes);
        setMinutesBefore(updated);
    }

    function reminderLabel(minutes) {
        if (minutes === 0)
            return "No horário";
        if (minutes % 10080 === 0) {
            const weeks = minutes / 10080;
            return weeks === 1 ? "1 semana antes" : weeks + " semanas antes";
        }
        if (minutes % 1440 === 0) {
            const days = minutes / 1440;
            return days === 1 ? "1 dia antes" : days + " dias antes";
        }
        if (minutes % 60 === 0) {
            const hours = minutes / 60;
            return hours === 1 ? "1 hora antes" : hours + " horas antes";
        }
        return minutes === 1 ? "1 minuto antes" : minutes + " minutos antes";
    }

    function customMinutes() {
        return customAmount.value * Number(customUnit.currentValue);
    }

    function addCustom() {
        const minutes = customMinutes();
        if (!contains(minutes) && minutesBefore.length < maximumCount)
            toggle(minutes);
    }

    AppButton {
        id: trigger
        anchors.fill: parent
        text: root.compact ? String(root.minutesBefore.length) : "Alertas · " + root.minutesBefore.length
        onClicked: reminderPopup.open()
        ToolTip.visible: hovered
        ToolTip.text: "Configurar até 5 notificações"
        Accessible.name: "Alertas · " + root.minutesBefore.length
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

    Popup {
        id: reminderPopup
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
            radius: WaypointTheme.radiusLarge
            color: WaypointTheme.popupFill
            border.width: 1
            border.color: WaypointTheme.controlBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap

            Text {
                text: "Notificações · " + root.minutesBefore.length + "/" + root.maximumCount
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.headingSize
                font.weight: WaypointTheme.weightSemiBold
                font.features: WaypointTheme.tabularNumbers
            }

            Repeater {
                model: root.presets

                AppButton {
                    id: presetButton
                    required property var modelData
                    Layout.fillWidth: true
                    flat: !selected
                    selected: root.contains(Number(modelData.minutes))
                    enabled: selected || root.minutesBefore.length < root.maximumCount
                    text: String(modelData.label)
                    onClicked: root.toggle(Number(modelData.minutes))
                    contentItem: RowLayout {
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: presetButton.text
                            color: !presetButton.enabled ? WaypointTheme.disabledText
                                 : presetButton.selected ? WaypointTheme.accent : WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySmallSize
                            font.weight: WaypointTheme.weightMedium
                            verticalAlignment: Text.AlignVCenter
                        }
                        AppIcon {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            visible: presetButton.selected
                            name: "check"
                            color: WaypointTheme.accent
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: WaypointTheme.divider
            }

            Text {
                text: "Personalizado"
                color: WaypointTheme.disabledText
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
                font.weight: WaypointTheme.weightMedium
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: WaypointTheme.controlGap

                AppSpinBox {
                    id: customAmount
                    from: 1
                    to: 999
                    value: 1
                }
                AppComboBox {
                    id: customUnit
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        {
                            text: "minuto(s)",
                            value: 1
                        },
                        {
                            text: "hora(s)",
                            value: 60
                        },
                        {
                            text: "dia(s)",
                            value: 1440
                        },
                        {
                            text: "semana(s)",
                            value: 10080
                        }
                    ]
                }
                AppButton {
                    text: "Adicionar"
                    enabled: !root.contains(root.customMinutes()) && root.minutesBefore.length < root.maximumCount
                    onClicked: root.addCustom()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.minutesBefore.length > 0
                text: root.minutesBefore.map(value => root.reminderLabel(value)).join(" · ")
                color: WaypointTheme.subduedText
                wrapMode: Text.Wrap
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.captionSize
            }

            RowLayout {
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                AppButton {
                    text: "Concluir"
                    highlighted: true
                    onClicked: reminderPopup.close()
                }
            }
        }
    }
}
