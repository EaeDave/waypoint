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

    implicitHeight: 46
    radius: 7
    color: "#101013"
    border.width: input.activeFocus ? 1 : 0
    border.color: "#8f7fe1"

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
            onAccepted: root.submit()
        }

        TextField {
            id: timeInput
            Layout.preferredWidth: 58
            text: root.scheduledTimeKey
            placeholderText: "HH:mm"
            color: "#d7d3dc"
            horizontalAlignment: TextInput.AlignHCenter
            font.family: "monospace"
            font.pixelSize: 12
            selectByMouse: true
            validator: RegularExpressionValidator {
                regularExpression: /(?:[01]\d|2[0-3]):[0-5]\d/
            }
            onTextEdited: root.scheduledTimeEdited = true
            background: Rectangle {
                radius: 5
                color: "#1b1a20"
                border.width: timeInput.activeFocus ? 1 : 0
                border.color: "#8f7fe1"
            }
            onAccepted: root.submit()
        }

        ToolButton {
            id: repeatButton
            text: root.selectedFrequency() === "none" ? "↻" : "↻ " + preset.currentText.toUpperCase()
            onClicked: repeatPopup.open()
            ToolTip.visible: hovered
            ToolTip.text: "Configurar repetição"
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

    Popup {
        id: repeatPopup
        x: Math.max(0, root.width - width)
        y: root.height + 6
        width: 390
        padding: 16
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 9
            color: "#17161b"
            border.width: 1
            border.color: "#34313b"
        }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                text: "REPETIÇÃO"
                color: "#aaa7ad"
                font.family: "monospace"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            ComboBox {
                id: preset
                Layout.fillWidth: true
                model: ["Não repetir", "Diariamente", "Semanalmente", "Mensalmente", "Anualmente", "Personalizado"]
            }

            GridLayout {
                visible: preset.currentIndex === 5
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 9

                Label { text: "Frequência" }
                ComboBox {
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

                Label { text: "A cada" }
                RowLayout {
                    SpinBox {
                        id: interval
                        from: 1
                        to: 99
                        value: 1
                    }
                    Label {
                        text: customFrequency.currentValue === "daily" ? "dia(s)" :
                              customFrequency.currentValue === "weekly" ? "semana(s)" :
                              customFrequency.currentValue === "monthly" ? "mês(es)" : "ano(s)"
                    }
                }

                Label {
                    text: "Somente em"
                }
                RowLayout {
                    visible: customFrequency.currentValue === "weekly"
                    spacing: 2
                    Repeater {
                        id: weekdayRepeater
                        model: ["S", "T", "Q", "Q", "S", "S", "D"]
                        CheckBox {
                            required property int index
                            required property string modelData
                            text: modelData
                            checked: (root.weekdayMask & (1 << index)) !== 0
                            padding: 2
                            onToggled: {
                                if (checked)
                                    root.weekdayMask |= 1 << index;
                                else
                                    root.weekdayMask &= ~(1 << index);
                            }
                        }
                    }
                }

                Label { text: "Termina" }
                ComboBox {
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

                Label {
                    visible: ending.currentValue === "onDate"
                    text: "Data final"
                }
                TextField {
                    id: untilDate
                    visible: ending.currentValue === "onDate"
                    Layout.fillWidth: true
                    placeholderText: "AAAA-MM-DD"
                    text: root.scheduledDateKey
                }

                Label {
                    visible: ending.currentValue === "afterCount"
                    text: "Ocorrências"
                }
                SpinBox {
                    id: occurrenceCount
                    visible: ending.currentValue === "afterCount"
                    from: 1
                    to: 999
                    value: 10
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Concluir"
                    onClicked: repeatPopup.close()
                }
            }
        }
    }
}
