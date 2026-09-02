pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var controller
    property string editingHabitId: ""
    property int weekdayMask: 127
    property string manualHabitId: ""

    spacing: 8

    function weekdayValues() {
        const values = [];
        for (let index = 0; index < 7; ++index) {
            if ((weekdayMask & (1 << index)) !== 0)
                values.push(index + 1);
        }
        return values;
    }

    function reminderValues() {
        return habitReminders.reminderTimes;
    }

    function openCreate() {
        editingHabitId = "";
        weekdayMask = 127;
        habitEmoji.emoji = "";
        habitTitle.text = "";
        goalInput.text = "1";
        unitInput.text = "";
        modeInput.currentIndex = 2;
        incrementInput.text = "1";
        habitReminders.setReminderTimes([]);
        editorPopup.open();
        habitTitle.forceActiveFocus();
    }

    function openEdit(habit) {
        editingHabitId = habit.id;
        weekdayMask = 0;
        for (const weekday of habit.weekdays)
            weekdayMask |= 1 << (weekday - 1);
        habitEmoji.emoji = habit.emoji || "";
        habitTitle.text = habit.title;
        goalInput.text = String(habit.targetAmount);
        unitInput.text = habit.unit || "";
        modeInput.currentIndex = modeInput.indexOfValue(habit.checkInMode);
        incrementInput.text = String(habit.incrementAmount);
        habitReminders.setReminderTimes(habit.reminderTimes);
        editorPopup.open();
        habitTitle.forceActiveFocus();
        habitTitle.selectAll();
    }

    function saveHabit() {
        if (habitTitle.text.trim() === "" || !goalInput.acceptableInput ||
                !incrementInput.acceptableInput || weekdayMask === 0)
            return;
        if (controller.saveHabit(
                editingHabitId, habitTitle.text.trim(), parseInt(goalInput.text), unitInput.text.trim(),
                modeInput.currentValue, parseInt(incrementInput.text), weekdayValues(), reminderValues(),
                habitEmoji.emoji))
            editorPopup.close();
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 18

        Text {
            text: "HÁBITOS"
            color: WaypointTheme.subduedText
            font.family: WaypointTheme.fontFamily
            font.pixelSize: WaypointTheme.bodySmallSize
            font.bold: true
            font.letterSpacing: 1
        }

        Item { Layout.fillWidth: true }

        AppButton {
            text: "+ HÁBITO"
            onClicked: root.openCreate()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.controller.todayHabits.length === 0
        text: "Nenhum hábito programado para hoje."
        color: WaypointTheme.disabledText
        font.family: WaypointTheme.fontFamily
        font.pixelSize: WaypointTheme.bodySmallSize
    }

    Repeater {
        model: root.controller.todayHabits

        delegate: Rectangle {
            id: habitRow
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: rowContent.implicitHeight + 20
            radius: WaypointTheme.radius
            color: WaypointTheme.controlFill
            border.width: 1
            border.color: WaypointTheme.controlBorder

            ColumnLayout {
                id: rowContent
                anchors.fill: parent
                anchors.margins: 10
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        visible: habitRow.modelData.emoji !== ""
                        text: habitRow.modelData.emoji
                        font.pixelSize: WaypointTheme.titleSize
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: habitRow.modelData.title
                            color: habitRow.modelData.completed ? WaypointTheme.subduedText : WaypointTheme.foreground
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySize
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: habitRow.modelData.amount + " / " + habitRow.modelData.targetAmount +
                                  (habitRow.modelData.unit === "" ? "" : " " + habitRow.modelData.unit)
                            color: habitRow.modelData.completed ? WaypointTheme.success : WaypointTheme.subduedText
                            font.family: WaypointTheme.fontFamily
                            font.pixelSize: WaypointTheme.bodySmallSize
                        }
                    }

                    Text {
                        visible: habitRow.modelData.reminderTimes.length > 0
                        text: "󰂚 " + habitRow.modelData.reminderTimes.length
                        color: WaypointTheme.disabledText
                        font.family: WaypointTheme.fontFamily
                        font.pixelSize: WaypointTheme.bodySmallSize
                    }

                    AppButton {
                        text: "↶"
                        square: true
                        enabled: habitRow.modelData.amount > 0
                        onClicked: root.controller.undoHabit(habitRow.modelData.id)
                        ToolTip.visible: hovered
                        ToolTip.text: "Desfazer último registro"
                    }

                    AppButton {
                        text: "Editar"
                        onClicked: root.openEdit(habitRow.modelData)
                    }

                    AppButton {
                        enabled: !habitRow.modelData.completed
                        text: habitRow.modelData.completed ? "Concluído"
                            : habitRow.modelData.checkInMode === "fixed"
                                ? "+" + habitRow.modelData.incrementAmount +
                                  (habitRow.modelData.unit === "" ? "" : " " + habitRow.modelData.unit)
                            : habitRow.modelData.checkInMode === "manual" ? "Registrar" : "Concluir"
                        selected: habitRow.modelData.completed
                        onClicked: {
                            if (habitRow.modelData.checkInMode === "manual") {
                                root.manualHabitId = habitRow.modelData.id;
                                manualAmount.text = "";
                                manualPopup.open();
                                manualAmount.forceActiveFocus();
                            } else {
                                root.controller.recordHabit(habitRow.modelData.id, 0);
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 3
                    radius: 2
                    color: WaypointTheme.divider

                    Rectangle {
                        width: parent.width * Math.min(1, habitRow.modelData.amount / habitRow.modelData.targetAmount)
                        height: parent.height
                        radius: parent.radius
                        color: habitRow.modelData.completed ? WaypointTheme.success : WaypointTheme.activeBorder
                    }
                }
            }
        }
    }

    Item {
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0

    Popup {
        id: manualPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(320, parent.width - 24)
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

            Text {
                text: "REGISTRAR PROGRESSO"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.titleSize
                font.bold: true
            }

            AppTextField {
                id: manualAmount
                Layout.fillWidth: true
                placeholderText: "Quantidade"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 1000000000 }
                onAccepted: {
                    if (acceptableInput && root.controller.recordHabit(root.manualHabitId, parseInt(text)))
                        manualPopup.close();
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                AppButton { text: "Cancelar"; onClicked: manualPopup.close() }
                AppButton {
                    text: "Registrar"
                    selected: true
                    enabled: manualAmount.acceptableInput
                    onClicked: {
                        if (root.controller.recordHabit(root.manualHabitId, parseInt(manualAmount.text)))
                            manualPopup.close();
                    }
                }
            }
        }
    }

    Popup {
        id: editorPopup
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(440, parent.width - 24)
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

            Text {
                text: root.editingHabitId === "" ? "NOVO HÁBITO" : "EDITAR HÁBITO"
                color: WaypointTheme.foreground
                font.family: WaypointTheme.fontFamily
                font.pixelSize: WaypointTheme.titleSize
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                AppEmojiPicker { id: habitEmoji }
                AppTextField {
                    id: habitTitle
                    Layout.fillWidth: true
                    placeholderText: "Título"
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 8

                Text {
                    text: "Meta diária"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                RowLayout {
                    Layout.fillWidth: true
                    AppTextField {
                        id: goalInput
                        Layout.fillWidth: true
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1; top: 1000000000 }
                    }
                    AppTextField {
                        id: unitInput
                        Layout.preferredWidth: 120
                        placeholderText: "Unidade"
                        maximumLength: 32
                    }
                }

                Text {
                    text: "Registro"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppComboBox {
                    id: modeInput
                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Incremento fixo", value: "fixed" },
                        { text: "Quantidade manual", value: "manual" },
                        { text: "Completar tudo", value: "complete" }
                    ]
                }

                Text {
                    visible: modeInput.currentValue === "fixed"
                    text: "Incremento"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppTextField {
                    id: incrementInput
                    visible: modeInput.currentValue === "fixed"
                    Layout.fillWidth: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 1000000000 }
                }

                Text {
                    text: "Dias"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                RowLayout {
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
                    text: "Lembretes"
                    color: WaypointTheme.subduedText
                    font.family: WaypointTheme.fontFamily
                    font.pixelSize: WaypointTheme.bodySmallSize
                }
                AppHabitReminderPicker {
                    id: habitReminders
                    Layout.fillWidth: true
                }
            }


            RowLayout {
                Layout.fillWidth: true
                AppButton {
                    visible: root.editingHabitId !== ""
                    text: "Excluir"
                    destructive: true
                    onClicked: {
                        if (root.controller.deleteHabit(root.editingHabitId))
                            editorPopup.close();
                    }
                }
                Item { Layout.fillWidth: true }
                AppButton { text: "Cancelar"; onClicked: editorPopup.close() }
                AppButton {
                    text: "Salvar"
                    selected: true
                    enabled: habitTitle.text.trim() !== "" && goalInput.acceptableInput &&
                             incrementInput.acceptableInput && root.weekdayMask !== 0
                    onClicked: root.saveHabit()
                }
            }
        }
    }
    }
}
