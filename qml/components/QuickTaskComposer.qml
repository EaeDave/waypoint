pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    required property var controller
    required property string scheduledDateKey
    property string placeholderText: "Nova tarefa…"
    property int weekdayMask: 0
    property string scheduledTimeKey: currentTimeKey()
    property bool scheduledTimeEdited: false

    implicitHeight: 44
    radius: WaypointTheme.radius
    color: input.activeFocus ? WaypointTheme.controlHoverFill : WaypointTheme.controlFill
    border.width: 1
    border.color: input.activeFocus ? WaypointTheme.activeBorder : WaypointTheme.controlBorder

    function focusInput() {
        input.forceActiveFocus();
    }
    function currentTimeKey() {
        return Qt.formatTime(new Date(), "HH:mm");
    }

    function anchorWeekdayIndex() {
        const parts = scheduledDateKey.split("-");
        const date = new Date(Number(parts[0]), Number(parts[1]) - 1,
                              Number(parts[2]));
        return (date.getDay() + 6) % 7;
    }

    function selectedFrequency() {
        if (preset.currentIndex === 1)
            return "daily";
        if (preset.currentIndex === 2)
            return "weekly";
        if (preset.currentIndex === 3)
            return "monthly";
        if (preset.currentIndex === 4)
            return "yearly";
        if (preset.currentIndex === 5)
            return customFrequency.currentValue;
        return "none";
    }

    function selectedWeekdays() {
        if (selectedFrequency() !== "weekly" || preset.currentIndex !== 5)
            return [];
        const selected = [];
        for (let index = 0; index < 7; ++index) {
            if ((weekdayMask & (1 << index)) !== 0)
                selected.push(index + 1);
        }
        return selected;
    }

    function submit() {
        const normalizedTitle = input.text.trim();
        if (normalizedTitle.length === 0)
            return;
        const custom = preset.currentIndex === 5;
        const endMode = custom ? ending.currentValue : "never";
        const scheduledTime = scheduledTimeEdited
                              ? timeInput.text.trim()
                              : currentTimeKey();
        if (root.controller.addTask(normalizedTitle, root.scheduledDateKey,
                                    scheduledTime, selectedFrequency(),
                                    custom ? interval.value : 1,
                                    selectedWeekdays(), endMode,
                                    endMode === "onDate" ? untilDate.text.trim() : "",
                                    endMode === "afterCount" ? occurrenceCount.value : 0)) {
            input.text = "";
            timeInput.text = root.currentTimeKey();
            scheduledTimeEdited = false;
            preset.currentIndex = 0;
            interval.value = 1;
            ending.currentIndex = 0;
            weekdayMask = 0;
            repeatPopup.close();
            input.forceActiveFocus();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        spacing: 8

        Text {
            text: "+"
            color: WaypointTheme.accent
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.headingSize
        }

        TextField {
            id: input
            Layout.fillWidth: true
            placeholderText: root.placeholderText
            color: WaypointTheme.foreground
            placeholderTextColor: WaypointTheme.disabledText
            selectionColor: WaypointTheme.accent
            selectedTextColor: WaypointTheme.background
            background: Item {}
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySize
            onAccepted: root.submit()
        }

        AppTextField {
            id: timeInput
            Layout.preferredWidth: 64
            Layout.preferredHeight: 30
            text: root.scheduledTimeKey
            placeholderText: "HH:mm"
            horizontalAlignment: TextInput.AlignHCenter
            inputMethodHints: Qt.ImhTime
            validator: RegularExpressionValidator {
                regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
            }
            onTextEdited: root.scheduledTimeEdited = true
            onAccepted: root.submit()
        }

        AppButton {
            id: repeatButton
            Layout.preferredHeight: 30
            text: root.selectedFrequency() === "none" ? "↻" : "↻ " + preset.currentText.toUpperCase()
            selected: root.selectedFrequency() !== "none"
            onClicked: repeatPopup.open()
            ToolTip.visible: hovered
            ToolTip.text: "Configurar repetição"
        }

        Text {
            visible: input.activeFocus
            text: "ENTER"
            color: WaypointTheme.disabledText
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.captionSize
            font.letterSpacing: 1
        }
    }

    Popup {
        id: repeatPopup
        x: Math.max(0, root.width - width)
        y: root.height + 6
        width: 420
        padding: WaypointTheme.popupPadding
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: WaypointTheme.radius
            color: WaypointTheme.background
            border.width: 1
            border.color: WaypointTheme.activeBorder
        }

        contentItem: ColumnLayout {
            spacing: WaypointTheme.controlGap

            Text {
                text: "REPETIÇÃO"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.titleSize
                font.bold: true
            }

            AppComboBox {
                id: preset
                Layout.fillWidth: true
                model: ["Não repetir", "Diariamente", "Semanalmente", "Mensalmente", "Anualmente", "Personalizado"]
            }

            GridLayout {
                visible: preset.currentIndex === 5
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 8

                Text {
                    text: "Frequência"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppComboBox {
                    id: customFrequency
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Diária", value: "daily" },
                        { text: "Semanal", value: "weekly" },
                        { text: "Mensal", value: "monthly" },
                        { text: "Anual", value: "yearly" }
                    ]
                    onCurrentValueChanged: {
                        if (currentValue === "weekly" && root.weekdayMask === 0)
                            root.weekdayMask = 1 << root.anchorWeekdayIndex();
                    }
                }

                Text {
                    text: "A cada"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                RowLayout {
                    AppSpinBox {
                        id: interval
                        from: 1
                        to: 99
                        value: 1
                    }
                    Text {
                        text: customFrequency.currentValue === "daily" ? "dia(s)"
                            : customFrequency.currentValue === "weekly" ? "semana(s)"
                            : customFrequency.currentValue === "monthly" ? "mês(es)" : "ano(s)"
                        color: WaypointTheme.subduedText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }
                }

                Text {
                    visible: customFrequency.currentValue === "weekly"
                    text: "Somente em"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                RowLayout {
                    visible: customFrequency.currentValue === "weekly"
                    spacing: 4
                    Repeater {
                        model: ["S", "T", "Q", "Q", "S", "S", "D"]
                        AppButton {
                            required property int index
                            required property string modelData
                            Layout.preferredWidth: 32
                            square: true
                            selected: (root.weekdayMask & (1 << index)) !== 0
                            text: modelData
                            onClicked: root.weekdayMask ^= 1 << index
                        }
                    }
                }

                Text {
                    text: "Termina"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppComboBox {
                    id: ending
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Nunca", value: "never" },
                        { text: "Em uma data", value: "onDate" },
                        { text: "Após ocorrências", value: "afterCount" }
                    ]
                }

                Text {
                    visible: ending.currentValue === "onDate"
                    text: "Data final"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppTextField {
                    id: untilDate
                    visible: ending.currentValue === "onDate"
                    Layout.fillWidth: true
                    placeholderText: "AAAA-MM-DD"
                    text: root.scheduledDateKey
                }

                Text {
                    visible: ending.currentValue === "afterCount"
                    text: "Ocorrências"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppSpinBox {
                    id: occurrenceCount
                    visible: ending.currentValue === "afterCount"
                    from: 1
                    to: 999
                    value: 10
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Item {
                    Layout.fillWidth: true
                }
                AppButton {
                    text: "Concluir"
                    selected: true
                    onClicked: repeatPopup.close()
                }
            }
        }
    }
}
